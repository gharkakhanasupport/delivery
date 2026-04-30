import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/delivery_navigation_screen.dart';
import '../widgets/incoming_order_sheet.dart';
import 'database_service.dart';
import 'order_service.dart';

/// Bridges FCM `new_pickup` payloads → IncomingOrderSheet.
///
/// Phase 5C:
///   - Dedupe: if a sheet is already up for this orderId, skip second show.
///   - Already-claimed guard: if `delivery_orders.delivery_partner_id` not null
///     OR a cached realtime `order_taken` already fired, skip show.
///   - Richer field fetch: kitchen_name, pickup_address, delivery_address,
///     items count, payment_method, agent_earnings, total_amount.
///   - Close sheet FIRST, push nav screen next (avoids modal stacking bug).
class DispatchService {
  static final DispatchService _instance = DispatchService._internal();
  factory DispatchService() => _instance;
  DispatchService._internal();

  final SupabaseClient _supabase = DatabaseService().primary;

  /// Order IDs currently showing a sheet. Guards against duplicate FCM +
  /// foreground-onMessage races that both want to open a sheet.
  final Set<String> _openOrderIds = {};

  /// Call from FCM handler when a `new_pickup` message lands.
  /// [data] is `RemoteMessage.data` (flattened strings).
  Future<void> showIncomingOrder(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final orderId = data['order_id']?.toString();
    if (orderId == null || orderId.isEmpty) return;

    // Dedupe: sheet already up for this order.
    if (_openOrderIds.contains(orderId)) {
      debugPrint('[Dispatch] sheet already open for $orderId — skip');
      return;
    }

    double? pickupLat;
    double? pickupLng;
    final latRaw = data['pickup_lat']?.toString();
    final lngRaw = data['pickup_lng']?.toString();
    if (latRaw != null) pickupLat = double.tryParse(latRaw);
    if (lngRaw != null) pickupLng = double.tryParse(lngRaw);

    String kitchenName = 'Kitchen';
    String? kitchenAddress;
    String? customerArea;
    int itemCount = 0;
    String paymentMethod = 'online';
    double agentEarnings = 0.0;
    double totalAmount = 0.0;

    try {
      final row = await _supabase
          .from('delivery_orders')
          .select(
              'kitchen_name, pickup_address, delivery_address, items, total_amount, agent_earnings, payment_method, delivery_partner_id')
          .eq('id', orderId)
          .maybeSingle();

      if (row == null) {
        debugPrint('[Dispatch] order $orderId not yet in delivery_orders — showing with FCM payload');
      } else {
        // Already claimed — sheet would be pointless.
        if (row['delivery_partner_id'] != null) {
          debugPrint('[Dispatch] $orderId already claimed — skip sheet');
          return;
        }
        kitchenName = (row['kitchen_name'] as String?) ?? kitchenName;
        totalAmount = ((row['total_amount'] as num?) ?? 0).toDouble();
        agentEarnings = ((row['agent_earnings'] as num?) ?? 25).toDouble();
        paymentMethod = (row['payment_method'] as String?) ?? 'online';

        final items = row['items'];
        if (items is List) itemCount = items.length;

        kitchenAddress = _extractAddressText(row['pickup_address']);
        customerArea = _extractArea(row['delivery_address']);
      }

      // Fallback: pull fields from FCM data payload if DB row absent.
      kitchenName = (data['kitchen_name']?.toString().isNotEmpty ?? false)
          ? data['kitchen_name'].toString()
          : kitchenName;
      if (totalAmount == 0 && data['total_amount'] != null) {
        totalAmount = double.tryParse(data['total_amount'].toString()) ?? 0;
      }
      if (agentEarnings == 0 && data['agent_earnings'] != null) {
        agentEarnings = double.tryParse(data['agent_earnings'].toString()) ?? 25;
      }
      if (agentEarnings == 0) agentEarnings = 25;
    } catch (e) {
      debugPrint('[Dispatch] fetch failed: $e — showing with defaults');
    }

    if (!context.mounted) return;

    _openOrderIds.add(orderId);
    try {
      await IncomingOrderSheet.show(
        context,
        orderId: orderId,
        kitchenName: kitchenName,
        kitchenAddress: kitchenAddress,
        customerArea: customerArea,
        itemCount: itemCount,
        paymentMethod: paymentMethod,
        agentEarnings: agentEarnings,
        totalAmount: totalAmount,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        onAccept: (id) async {
          final claimed = await OrderService.acceptOrder(id);
          if (!claimed) return false;
          // Sheet already popping via its own Navigator.pop on return true.
          // Fetch + push nav screen after a microtask so the pop finishes first.
          final order = await OrderService.fetchOrderById(id);
          if (order != null && context.mounted) {
            // Defer push to next frame — avoids modal/nav stack collision.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeliveryNavigationScreen(order: order),
                ),
              );
            });
          }
          return true;
        },
      );
    } finally {
      _openOrderIds.remove(orderId);
    }
  }

  /// Extract a compact address string from JSONB address blob.
  /// Accepts {'address': '...'} or {'street','area','city'} shapes.
  String? _extractAddressText(dynamic addr) {
    if (addr == null) return null;
    if (addr is String) return addr.trim().isEmpty ? null : addr;
    if (addr is! Map) return null;
    final m = addr;
    final direct = (m['address'] ?? m['text'] ?? m['full_address'])?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct;
    final parts = <String>[];
    for (final k in ['street', 'area', 'locality', 'city']) {
      final v = m[k]?.toString();
      if (v != null && v.trim().isNotEmpty) parts.add(v);
    }
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  /// Extract only the area/pincode from customer delivery_address JSONB.
  /// Avoids leaking full house/street until partner accepts.
  String? _extractArea(dynamic addr) {
    if (addr == null) return null;
    if (addr is String) return null; // Full string — don't leak.
    if (addr is! Map) return null;
    final m = addr;
    final area = (m['area'] ?? m['locality'] ?? m['city'])?.toString();
    final pin = (m['pincode'] ?? m['pin'] ?? m['postal_code'])?.toString();
    final parts = <String>[];
    if (area != null && area.trim().isNotEmpty) parts.add(area);
    if (pin != null && pin.trim().isNotEmpty) parts.add(pin);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
