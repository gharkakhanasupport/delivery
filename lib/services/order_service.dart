import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order.dart';
import 'database_service.dart';
import 'geocoding_service.dart';
import 'online_service.dart';

/// Service for managing delivery orders
///
/// Architecture:
/// - Orders ORIGINATE in the User DB (`orders` table)
/// - When an order is ready, it gets SYNCED to the Delivery DB (`delivery_orders`)
/// - The delivery agent accepts/updates in delivery_orders
/// - Status updates are synced BACK to User DB
///
/// Uses service role keys for cross-database reads.
class OrderService {
  static final SupabaseClient _deliveryDb = DatabaseService().primary;
  static final DatabaseService _db = DatabaseService();

  // ================================================================
  // FETCHING AVAILABLE ORDERS (from User DB → sync to Delivery DB)
  // ================================================================

  /// Fetch orders available for pickup.
  /// 1. First checks delivery_orders in Delivery DB (already synced)
  /// 2. Then fetches NEW orders from User DB and syncs them
  static Future<List<Order>> fetchAvailableOrders() async {
    try {
      // Step 1: Sync new orders from User DB into delivery_orders
      await _syncOrdersFromUserDb();

      // Step 2: Read from our local delivery_orders table
      final response = await _deliveryDb
          .from('delivery_orders')
          .select()
          .inFilter('status', ['pending', 'confirmed', 'preparing', 'ready', 'ready_for_pickup'])
          .isFilter('delivery_partner_id', null)
          .order('created_at', ascending: false)
          .limit(50); // Increased limit as we'll filter by distance now

      final List<Order> allOrders = (response as List).map((json) => Order.fromJson(json)).toList();
      return _filterOrdersWithinRadius(allOrders, 5000); // 5km radius
    } catch (e) {
      debugPrint('[OrderService] Error fetching available orders: $e');
      // Fallback: try fetching directly from User DB
      final List<Order> fbOrders = await _fetchOrdersDirectlyFromUserDb();
      return _filterOrdersWithinRadius(fbOrders, 5000);
    }
  }

  static List<Order> _filterOrdersWithinRadius(List<Order> orders, double radiusInMeters) {
    final currentPos = OnlineService.currentPosition;
    if (currentPos == null) {
      // If we don't have location yet, return all to not show false empty screen
      return orders;
    }
    
    return orders.where((order) {
      final distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        order.location.latitude,
        order.location.longitude,
      );
      return distance <= radiusInMeters;
    }).toList();
  }

  /// Sync orders from User DB → Delivery DB
  /// Pulls orders with status 'pending','confirmed','preparing','ready_for_pickup'
  /// and upserts them into delivery_orders
  /// Pulls orders from User DB via Edge Function
  static Future<void> _syncOrdersFromUserDb() async {
    try {
      final response = await _deliveryDb.functions.invoke('fetch-user-orders');
      
      if (response.status != 200 || response.data == null) {
        debugPrint('[OrderService] fetch-user-orders returned status ${response.status}');
        return;
      }

      final userOrders = response.data as List<dynamic>;
      if (userOrders.isEmpty) return;

      for (final userOrder in userOrders) {
        final orderId = userOrder['id'] as String;

        // Skip orders already synced to delivery_orders with assigned partners
        try {
          final existing = await _deliveryDb
              .from('delivery_orders')
              .select('id, delivery_partner_id')
              .eq('id', orderId)
              .maybeSingle();
          if (existing != null) {
            // Already synced — only update status if unassigned
            if (existing['delivery_partner_id'] == null) {
              await _deliveryDb
                  .from('delivery_orders')
                  .update({
                    'status': userOrder['status'],
                    'last_synced_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', orderId);
            }
            continue; // Skip full upsert
          }
        } catch (_) {}
        
        // Extract Edge Function enriched data
        final kitchenDetails = userOrder['kitchen_details'] as Map<String, dynamic>?;
        String kitchenName = kitchenDetails?['kitchen_name'] as String? ?? 'Kitchen';
        String kitchenPhone = kitchenDetails?['phone'] as String? ?? '';
        String kitchenLocation = kitchenDetails?['location'] as String? ?? '';
        double kitchenLat = 0.0;
        double kitchenLng = 0.0;

        if (kitchenLocation.isNotEmpty) {
          final kitchenCoords = await GeocodingService.geocodeAddress(kitchenLocation);
          if (kitchenCoords != null) {
            kitchenLat = kitchenCoords.latitude;
            kitchenLng = kitchenCoords.longitude;
          }
        }

        // Resolve delivery address
        final resolvedAddr = userOrder['resolved_delivery_address'] as Map<String, dynamic>?;
        String deliveryAddrText = userOrder['delivery_address'] as String? ?? '';
        double deliveryLat = 0.0;
        double deliveryLng = 0.0;

        if (resolvedAddr != null) {
          deliveryLat = (resolvedAddr['latitude'] as num?)?.toDouble() ?? 0.0;
          deliveryLng = (resolvedAddr['longitude'] as num?)?.toDouble() ?? 0.0;
          deliveryAddrText = resolvedAddr['full_address'] as String? ??
              [
                resolvedAddr['street_address'],
                resolvedAddr['area'],
                resolvedAddr['city'],
              ].where((s) => s != null && s.toString().isNotEmpty).join(', ');
        } else if (deliveryAddrText.isNotEmpty && !GeocodingService.isUuid(deliveryAddrText)) {
          final coords = await GeocodingService.geocodeAddress(deliveryAddrText);
          if (coords != null) {
            deliveryLat = coords.latitude;
            deliveryLng = coords.longitude;
          }
        }

        // If still no coordinates, try geocoding the text address
        if (deliveryLat == 0.0 && deliveryLng == 0.0 && deliveryAddrText.isNotEmpty) {
          final coords = await GeocodingService.geocodeAddress(deliveryAddrText);
          if (coords != null) {
            deliveryLat = coords.latitude;
            deliveryLng = coords.longitude;
          }
        }

        // TEST MODE: use fallback coords when missing (emulator / incomplete addr).
        // Previously skipped orders — that broke the entire pipeline.
        if (deliveryLat == 0.0 || deliveryLng == 0.0) {
          debugPrint('[OrderService] Order $orderId missing delivery coords — using fallback');
          deliveryLat = 12.9716; // Bangalore center fallback
          deliveryLng = 77.5946;
        }
        if (kitchenLat == 0.0 || kitchenLng == 0.0) {
          debugPrint('[OrderService] Order $orderId missing kitchen coords — using fallback');
          kitchenLat = 12.9716;
          kitchenLng = 77.5946;
        }

        // Build the delivery_orders row
        final deliveryOrderData = {
          'id': orderId,
          'order_number': 'GKK-${orderId.substring(0, 8).toUpperCase()}',
          'source_db': 'user',
          'source_order_id': orderId,
          // Kitchen info
          'kitchen_id': userOrder['cook_id'],
          'kitchen_name': kitchenName,
          'kitchen_phone': kitchenPhone,
          'kitchen_location': kitchenLocation,
          // Pickup address (kitchen — with REAL coordinates)
          'pickup_address': {
            'address': kitchenLocation,
            'lat': kitchenLat,
            'lng': kitchenLng,
          },
          // Customer info
          'user_id': userOrder['customer_id'],
          'user_name': userOrder['customer_name'],
          'user_phone': userOrder['customer_phone'],
          // Delivery address (customer — with REAL coordinates)
          'delivery_address': {
            'address': deliveryAddrText,
            'lat': deliveryLat,
            'lng': deliveryLng,
          },
          'delivery_address_text': deliveryAddrText,
          // Items & financials
          'items': userOrder['items'],
          'total_amount': userOrder['total_amount'] ?? 0,
          'delivery_fee': 30.0,
          'agent_earnings': 25.0,
          'payment_method': userOrder['payment_method'] ?? 'online',
          // Status
          'status': userOrder['status'],
          // Timestamps
          'created_at': userOrder['created_at'],
          'updated_at': userOrder['updated_at'],
          'last_synced_at': DateTime.now().toIso8601String(),
          'last_synced_from': 'user_db',
        };

        // Upsert into delivery_orders (won't overwrite agent assignments)
        try {
          // Check if already exists with an agent assigned
          final existing = await _deliveryDb
              .from('delivery_orders')
              .select('delivery_partner_id, status')
              .eq('id', orderId)
              .maybeSingle();

          if (existing != null && existing['delivery_partner_id'] != null) {
            // Already assigned to an agent, only update status from source
            await _deliveryDb
                .from('delivery_orders')
                .update({
                  'status': userOrder['status'],
                  'last_synced_at': DateTime.now().toIso8601String(),
                })
                .eq('id', orderId);
          } else {
            // New order or unassigned — full upsert
            await _deliveryDb
                .from('delivery_orders')
                .upsert(deliveryOrderData, onConflict: 'id');
          }
        } catch (e) {
          debugPrint('[OrderService] Upsert failed for order $orderId: $e');
        }
      }
    } catch (e) {
      debugPrint('[OrderService] Sync from User DB failed: $e');
    }
  }

  /// Fallback: Read orders directly from User DB without syncing
  static Future<List<Order>> _fetchOrdersDirectlyFromUserDb() async {
    final userClient = _db.userDb;
    if (userClient == null) return [];

    try {
      final response = await userClient
          .from('orders')
          .select()
          .inFilter('status', ['pending', 'confirmed', 'preparing', 'ready', 'ready_for_pickup'])
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List).map((json) {
        // Map User DB order format to our Order model
        return Order.fromJson({
          ...json,
          'kitchen_name': 'Kitchen',
          'order_number': 'GKK-${(json['id'] as String).substring(0, 8).toUpperCase()}',
          'delivery_address_text': json['delivery_address'],
          'agent_earnings': 25.0,
          'delivery_fee': 30.0,
        });
      }).toList();
    } catch (e) {
      debugPrint('[OrderService] Direct User DB fetch failed: $e');
      return [];
    }
  }

  // ================================================================
  // ACTIVE ORDERS (Assigned to current agent)
  // ================================================================

  /// Fetch orders assigned to the current agent (active deliveries)
  static Future<List<Order>> fetchActiveOrders() async {
    final userId = _deliveryDb.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _deliveryDb
          .from('delivery_orders')
          .select()
          .eq('delivery_partner_id', userId)
          .inFilter('status', ['assigned', 'picked_up', 'out_for_delivery'])
          .order('assigned_at', ascending: false);

      return (response as List).map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[OrderService] Error fetching active orders: $e');
      return [];
    }
  }

  /// Fetch a single delivery order by id.
  static Future<Order?> fetchOrderById(String orderId) async {
    try {
      final row = await _deliveryDb
          .from('delivery_orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();
      if (row == null) return null;
      return Order.fromJson(row);
    } catch (e) {
      debugPrint('[OrderService] fetchOrderById failed: $e');
      return null;
    }
  }

  /// Fetch order history (completed and cancelled)
  static Future<List<Order>> fetchOrderHistory({int limit = 50}) async {
    final userId = _deliveryDb.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _deliveryDb
          .from('delivery_orders')
          .select()
          .eq('delivery_partner_id', userId)
          .inFilter('status', ['delivered', 'cancelled'])
          .order('delivered_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[OrderService] Error fetching order history: $e');
      return [];
    }
  }

  // ================================================================
  // ORDER ACTIONS (Updates Delivery DB + syncs back to User DB)
  // ================================================================

  /// Accept an order — assign it to the current agent.
  ///
  /// Steps:
  /// 1. Single-winner claim on delivery_orders via WHERE delivery_partner_id IS NULL.
  /// 2. Broadcast `order_taken` event on realtime so other partners' sheets dismiss.
  /// 3. Cross-PATCH User DB (out_for_delivery + partner id).
  /// 4. Cross-PATCH Kitchen DB (partner id) — required for get_pickup_otp RPC guard.
  /// 5. Log status change.
  static Future<bool> acceptOrder(String orderId) async {
    final userId = _deliveryDb.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final now = DateTime.now().toIso8601String();

      // 0. Ensure row exists in delivery_orders. Synced lazily from User DB
      //    if missing (FCM can arrive before background sync).
      final existing = await _deliveryDb
          .from('delivery_orders')
          .select('id, delivery_partner_id')
          .eq('id', orderId)
          .maybeSingle();

      if (existing == null) {
        debugPrint('[OrderService] delivery_orders row missing for $orderId — syncing now');
        await _syncOrdersFromUserDb();
        final retry = await _deliveryDb
            .from('delivery_orders')
            .select('id')
            .eq('id', orderId)
            .maybeSingle();
        if (retry == null) {
          debugPrint('[OrderService] sync did not produce row for $orderId');
          return false;
        }
      } else if (existing['delivery_partner_id'] != null &&
          existing['delivery_partner_id'] != userId) {
        debugPrint('[OrderService] Order $orderId claimed by another partner');
        return false;
      }

      // 1. Claim in delivery_orders — single-winner guard via WHERE IS NULL.
      //    If another partner claimed it first, 0 rows return → bail out.
      final claimed = await _deliveryDb
          .from('delivery_orders')
          .update({
            'delivery_partner_id': userId,
            'status': 'assigned',
            'assigned_at': now,
          })
          .eq('id', orderId)
          .isFilter('delivery_partner_id', null)
          .select('id');

      if ((claimed as List).isEmpty) {
        debugPrint('[OrderService] Order $orderId already claimed');
        return false;
      }

      // 2. Broadcast order_taken so other partners' sheets auto-dismiss.
      //    Best-effort — failure here is non-fatal.
      try {
        final ch = _deliveryDb.channel('order_taken');
        ch.subscribe();
        await ch.sendBroadcastMessage(
          event: 'taken',
          payload: {'order_id': orderId, 'by': userId},
        );
        // Unsubscribe after send — one-shot broadcast.
        await _deliveryDb.removeChannel(ch);
      } catch (e) {
        debugPrint('[OrderService] order_taken broadcast failed: $e');
      }

      // 3. Cross-PATCH User DB — ONLY partner_id, NOT status.
      //    Status stays 'ready' until cook verifies pickup OTP.
      final userClient = _db.userDb;
      if (userClient != null) {
        try {
          await userClient
              .from('orders')
              .update({'delivery_partner_id': userId})
              .eq('id', orderId);
        } catch (e) {
          debugPrint('[OrderService] User partner_id PATCH failed: $e');
        }
      }

      // 4. Cross-PATCH Kitchen DB — ONLY partner_id (required by
      //    get_pickup_otp_for_partner RPC auth guard). NOT status.
      final kitchenClient = _db.kitchenDb;
      if (kitchenClient != null) {
        try {
          await kitchenClient
              .from('orders')
              .update({'delivery_partner_id': userId})
              .eq('id', orderId);
        } catch (e) {
          debugPrint('[OrderService] Kitchen partner_id PATCH failed: $e');
        }
      }

      // 5. Log status change
      await _logStatusChange(
        orderId: orderId,
        previousStatus: 'ready_for_pickup',
        newStatus: 'assigned',
        userId: userId,
      );

      return true;
    } catch (e) {
      debugPrint('[OrderService] Error accepting order: $e');
      return false;
    }
  }

  /// Update order status (picked_up, out_for_delivery, delivered, cancelled)
  static Future<bool> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? previousStatus,
    double? latitude,
    double? longitude,
    String? notes,
    bool isCod = false,
    double orderTotal = 0,
  }) async {
    final userId = _deliveryDb.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      // Phase D: COD Reverse Liability via DB RPC
      if (newStatus == OrderStatus.delivered && isCod) {
        try {
          final deliveryFee = 30.0;
          await _deliveryDb.rpc('debit_agent_wallet', params: {'p_agent_id': userId, 'p_amount': orderTotal});
          await _deliveryDb.rpc('credit_agent_wallet', params: {'p_agent_id': userId, 'p_amount': deliveryFee});
        } catch(e) {
          debugPrint('[OrderService] Error handling COD liability: $e');
        }
      }

      final updateData = <String, dynamic>{'status': newStatus.dbValue};

      // Add timestamp based on status
      switch (newStatus) {
        case OrderStatus.pickedUp:
          updateData['picked_up_at'] = DateTime.now().toIso8601String();
          break;
        case OrderStatus.outForDelivery:
          updateData['out_for_delivery_at'] = DateTime.now().toIso8601String();
          break;
        case OrderStatus.delivered:
          updateData['delivered_at'] = DateTime.now().toIso8601String();
          break;
        case OrderStatus.cancelled:
          updateData['cancelled_at'] = DateTime.now().toIso8601String();
          if (notes != null) updateData['cancellation_reason'] = notes;
          break;
        default:
          break;
      }

      // Update current location if provided
      if (latitude != null && longitude != null) {
        updateData['current_location'] = {
          'lat': latitude,
          'lng': longitude,
          'updated_at': DateTime.now().toIso8601String(),
        };
      }

      // 1. Update in delivery_orders
      await _deliveryDb
          .from('delivery_orders')
          .update(updateData)
          .eq('id', orderId)
          .eq('delivery_partner_id', userId);

      // 2. Sync status back to User DB
      await _syncStatusToUserDb(orderId, newStatus.dbValue);

      // 3. Earnings are credited ONLY via EarningsCreditService in the
      //    DeliveryNavigationScreen after OTP verification — NOT here.
      //    This eliminates the double-credit race between updateOrderStatus
      //    and the nav screen both calling WalletService.processDeliveryEarnings.

      // 4. Log status change
      await _logStatusChange(
        orderId: orderId,
        previousStatus: previousStatus,
        newStatus: newStatus.dbValue,
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
      );

      return true;
    } catch (e) {
      debugPrint('[OrderService] Error updating order status: $e');
      return false;
    }
  }

  /// Sync status update back to User DB's `orders` table.
  /// Also syncs to Kitchen DB so the cook sees the updated status.
  ///
  /// ## Dual-Sync Architecture (intentional)
  /// This client-side sync provides IMMEDIATE UX feedback (sub-100ms).
  /// The Edge Function `gkk-delivery-sync` (deployed on Delivery DB Supabase)
  /// provides a reliable server-side backup that fires via webhook.
  /// Both writes are IDEMPOTENT — same UPDATE with same status value —
  /// so no race condition can cause data corruption.
  ///
  /// The Edge Function does NOT sync to Kitchen DB, so this method is
  /// the ONLY path for Kitchen DB status updates from Delivery.
  ///
  /// [extraFields] lets callers write additional columns (e.g. delivery_partner_id, current_location).
  static Future<void> _syncStatusToUserDb(
    String orderId,
    String newStatus, {
    Map<String, dynamic>? extraFields,
  }) async {
    final updateData = <String, dynamic>{
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (newStatus == 'delivered') {
      updateData['completed_at'] = DateTime.now().toIso8601String();
      updateData['delivered_at'] = DateTime.now().toIso8601String();
    }

    if (extraFields != null) {
      updateData.addAll(extraFields);
    }

    // Sync to User DB (so customer tracking screen updates live)
    final userClient = _db.userDb;
    if (userClient != null) {
      try {
        await userClient
            .from('orders')
            .update(updateData)
            .eq('id', orderId);
        debugPrint('[OrderService] Synced status "$newStatus" to User DB');
      } catch (e) {
        debugPrint('[OrderService] Failed to sync to User DB: $e');
      }
    }

    // Sync to Kitchen DB (so cook sees the status update)
    final kitchenClient = _db.kitchenDb;
    if (kitchenClient != null) {
      try {
        await kitchenClient
            .from('orders')
            .update(updateData)
            .eq('id', orderId);
        debugPrint('[OrderService] Synced status "$newStatus" to Kitchen DB');
      } catch (e) {
        debugPrint('[OrderService] Failed to sync to Kitchen DB: $e');
      }
    }
  }

  /// Stream the delivery agent's live GPS location to the order row.
  /// Called periodically during out-for-delivery state.
  /// Updates User DB + Kitchen DB + Delivery DB with current_location JSONB.
  static Future<void> streamLocationToOrder(
    String orderId,
    double lat,
    double lng,
  ) async {
    final location = {
      'lat': lat,
      'lng': lng,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Update delivery_orders
    try {
      await _deliveryDb
          .from('delivery_orders')
          .update({'current_location': location})
          .eq('id', orderId);
    } catch (e) {
      debugPrint('[OrderService] streamLocation: delivery_orders failed: $e');
    }

    // Update orders in User DB
    final userClient = _db.userDb;
    if (userClient != null) {
      try {
        await userClient
            .from('orders')
            .update({'current_location': location})
            .eq('id', orderId);
      } catch (e) {
        debugPrint('[OrderService] streamLocation: user DB failed: $e');
      }
    }
  }



  /// Update delivery partner's current location on an active order
  static Future<bool> updateCurrentLocation(
    String orderId, {
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) async {
    final userId = _deliveryDb.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final locationData = {
        'lat': latitude,
        'lng': longitude,
        'heading': heading,
        'speed': speed,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _deliveryDb
          .from('delivery_orders')
          .update({'current_location': locationData})
          .eq('id', orderId)
          .eq('delivery_partner_id', userId);

      // Store in location history
      await _deliveryDb.from('location_history').insert({
        'partner_id': userId,
        'order_id': orderId,
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading,
        'speed': speed,
      });

      return true;
    } catch (e) {
      debugPrint('[OrderService] Error updating location: $e');
      return false;
    }
  }

  // ================================================================
  // HELPER METHODS
  // ================================================================

  static Future<void> _logStatusChange({
    required String orderId,
    String? previousStatus,
    required String newStatus,
    required String userId,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    try {
      await _deliveryDb.from('order_status_history').insert({
        'order_id': orderId,
        'previous_status': previousStatus,
        'new_status': newStatus,
        'changed_by': userId,
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
      });
    } catch (e) {
      debugPrint('[OrderService] Error logging status change: $e');
    }
  }

  // ================================================================
  // EARNINGS & STATISTICS
  // ================================================================

  /// Get today's earnings for the current agent
  static Future<double> getTodayEarnings() async {
    final userId = _deliveryDb.auth.currentUser?.id;
    if (userId == null) return 0.0;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _deliveryDb
          .from('wallet_transactions')
          .select('amount')
          .eq('agent_id', userId)
          .eq('type', 'credit')
          .gte('created_at', startOfDay.toIso8601String());

      double total = 0;
      for (var record in response) {
        total += (record['amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('[OrderService] Error fetching today earnings: $e');
      return 0.0;
    }
  }

  /// Get today's delivery count for the current agent
  static Future<int> getTodayDeliveryCount() async {
    final userId = _deliveryDb.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _deliveryDb
          .from('delivery_orders')
          .select('id')
          .eq('delivery_partner_id', userId)
          .eq('status', 'delivered')
          .gte('delivered_at', startOfDay.toIso8601String());

      return (response as List).length;
    } catch (e) {
      debugPrint('[OrderService] Error fetching today delivery count: $e');
      return 0;
    }
  }

  // ================================================================
  // REAL-TIME SUBSCRIPTIONS
  // ================================================================

  /// Subscribe to order updates for the current agent
  static RealtimeChannel subscribeToOrderUpdates(
    void Function(Order order) onUpdate,
  ) {
    final userId = _deliveryDb.auth.currentUser?.id;

    return _deliveryDb
        .channel('delivery-orders-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'delivery_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'delivery_partner_id',
            value: userId,
          ),
          callback: (payload) {
            try {
              final order = Order.fromJson(payload.newRecord);
              onUpdate(order);
            } catch (e) {
              debugPrint('[OrderService] Error parsing order update: $e');
            }
          },
        )
        .subscribe();
  }

  /// DEV / BETA TOOL — clear every delivery_orders row for this agent.
  /// Returns rows deleted. Does NOT touch User/Kitchen DBs (those wipe from
  /// their own apps).
  static Future<int> clearAllMyDeliveries() async {
    final agentId = Supabase.instance.client.auth.currentUser?.id;
    if (agentId == null) throw Exception('Not logged in');

    try {
      final del = await _deliveryDb
          .from('delivery_orders')
          .delete()
          .eq('delivery_partner_id', agentId)
          .select('id');
      return (del as List).length;
    } catch (e) {
      debugPrint('[OrderService] clearAllMyDeliveries failed: $e');
      rethrow;
    }
  }

  /// Subscribe to new available orders
  static RealtimeChannel subscribeToNewOrders(
    void Function(Order order) onNewOrder,
  ) {
    return _deliveryDb
        .channel('new-delivery-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'delivery_orders',
          callback: (payload) {
            try {
              final order = Order.fromJson(payload.newRecord);
              onNewOrder(order);
            } catch (e) {
              debugPrint('[OrderService] Error parsing new order: $e');
            }
          },
        )
        .subscribe();
  }
}
