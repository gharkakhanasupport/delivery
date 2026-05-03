import 'package:latlong2/latlong.dart';

/// Order status enum - Matches sync status values across all databases
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  readyForPickup,
  assigned,
  pickedUp,
  outForDelivery,
  delivered,
  cancelled;

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.confirmed:
        return 'CONFIRMED';
      case OrderStatus.preparing:
        return 'PREPARING';
      case OrderStatus.readyForPickup:
        return 'READY FOR PICKUP';
      case OrderStatus.assigned:
        return 'ASSIGNED';
      case OrderStatus.pickedUp:
        return 'PICKED UP';
      case OrderStatus.outForDelivery:
        return 'OUT FOR DELIVERY';
      case OrderStatus.delivered:
        return 'DELIVERED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  /// Database value - use this when sending to Supabase
  String get dbValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.readyForPickup:
        return 'ready_for_pickup';
      case OrderStatus.assigned:
        return 'assigned';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  static OrderStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
      case 'ready_for_pickup':
        return OrderStatus.readyForPickup;
      case 'assigned':
        return OrderStatus.assigned;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

/// Model representing a delivery order
/// Updated to support multi-database sync with User DB and Admin DB
class Order {
  final String id;
  final String orderNumber;

  // Restaurant/Kitchen info (synced from Cook DB)
  final String restaurantName;
  final String restaurantAddress;
  final String? restaurantPhone;
  final LatLng location; // Pickup location

  // Customer info (synced from User DB)
  final String? userId;
  final String? userName;
  final String? userPhone;
  final LatLng deliveryLocation;
  final String userAddress;
  final String? deliveryInstructions;

  // Order details
  final List<OrderItem> items;
  final double totalAmount;
  final double deliveryFee;
  final double earnings;
  final double distance;
  final int estimatedTime;
  final String paymentMethod;

  // Status tracking
  final OrderStatus status;
  final DeliveryLocation? currentLocation;

  // Timestamps
  final DateTime createdAt;
  final DateTime? readyAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  // Sync metadata
  final DateTime? lastSyncedAt;
  final String? lastSyncedFrom;

  // OTPs (Module 3 — double handoff)
  final String? pickupOtp;
  final String? deliveryOtp;

  /// Get a 4-character short ID for map display
  String get shortId => id.length >= 4 ? id.substring(0, 4).toUpperCase() : id;

  /// True when the order should be handled as cash on delivery.
  bool get isCashOnDelivery {
    final method = paymentMethod.trim().toLowerCase();
    return method == 'cash' || method == 'cod' || method == 'cod_cash';
  }

  Order({
    required this.id,
    required this.orderNumber,
    required this.restaurantName,
    required this.restaurantAddress,
    this.restaurantPhone,
    required this.location,
    this.userId,
    this.userName,
    this.userPhone,
    required this.deliveryLocation,
    required this.userAddress,
    this.deliveryInstructions,
    this.items = const [],
    required this.totalAmount,
    required this.deliveryFee,
    required this.earnings,
    required this.distance,
    required this.estimatedTime,
    this.paymentMethod = 'online',
    this.status = OrderStatus.pending,
    this.currentLocation,
    required this.createdAt,
    this.readyAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.lastSyncedAt,
    this.lastSyncedFrom,
    this.pickupOtp,
    this.deliveryOtp,
  });

  // Backward compatibility getters
  String get address => userAddress;

  /// Factory constructor for orders from delivery_orders table (synced)
  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse pickup address (JSONB or individual columns)
    LatLng pickupLocation;
    String pickupAddress;

    if (json['pickup_address'] != null && json['pickup_address'] is Map) {
      final pickup = json['pickup_address'] as Map<String, dynamic>;
      pickupLocation = LatLng(
        (pickup['lat'] as num?)?.toDouble() ?? 0.0,
        (pickup['lng'] as num?)?.toDouble() ?? 0.0,
      );
      pickupAddress = pickup['address'] as String? ?? '';
    } else {
      // Fallback to individual columns (legacy format)
      pickupLocation = LatLng(
        (json['restaurant_latitude'] as num?)?.toDouble() ?? 0.0,
        (json['restaurant_longitude'] as num?)?.toDouble() ?? 0.0,
      );
      pickupAddress = json['restaurant_address'] as String? ?? '';
    }

    // Parse delivery address (JSONB or individual columns)
    LatLng deliveryLoc;
    String deliveryAddr;

    if (json['delivery_address'] != null && json['delivery_address'] is Map) {
      final delivery = json['delivery_address'] as Map<String, dynamic>;
      deliveryLoc = LatLng(
        (delivery['lat'] as num?)?.toDouble() ?? 0.0,
        (delivery['lng'] as num?)?.toDouble() ?? 0.0,
      );
      deliveryAddr = delivery['address'] as String? ?? '';
    } else {
      deliveryLoc = LatLng(
        (json['delivery_latitude'] as num?)?.toDouble() ?? 0.0,
        (json['delivery_longitude'] as num?)?.toDouble() ?? 0.0,
      );
      deliveryAddr =
          json['delivery_address_text'] as String? ??
          json['delivery_address'] as String? ??
          '';
    }

    // Parse current location
    DeliveryLocation? currentLoc;
    if (json['current_location'] != null && json['current_location'] is Map) {
      currentLoc = DeliveryLocation.fromJson(
        json['current_location'] as Map<String, dynamic>,
      );
    }

    // Parse items
    List<OrderItem> orderItems = [];
    if (json['items'] != null && json['items'] is List) {
      orderItems = (json['items'] as List)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['order_items'] != null && json['order_items'] is List) {
      orderItems = (json['order_items'] as List)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Order(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String? ?? '',
      restaurantName:
          json['kitchen_name'] as String? ??
          json['restaurant_name'] as String? ??
          'Unknown',
      restaurantAddress: pickupAddress,
      restaurantPhone:
          json['kitchen_phone'] as String? ??
          json['restaurant_phone'] as String?,
      location: pickupLocation,
      userId: json['user_id'] as String?,
      userName:
          json['user_name'] as String? ?? json['customer_name'] as String?,
      userPhone:
          json['user_phone'] as String? ?? json['customer_phone'] as String?,
      deliveryLocation: deliveryLoc,
      userAddress: deliveryAddr,
      deliveryInstructions: json['delivery_instructions'] as String?,
      items: orderItems,
      totalAmount:
          (json['total_amount'] as num?)?.toDouble() ??
          (json['order_total'] as num?)?.toDouble() ??
          0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      earnings: (json['agent_earnings'] as num?)?.toDouble() ?? 25.0,
      distance:
          (json['estimated_distance_km'] as num?)?.toDouble() ??
          (json['distance_km'] as num?)?.toDouble() ??
          0.0,
      estimatedTime:
          (json['estimated_time_minutes'] as num?)?.toInt() ??
          (json['estimated_time_mins'] as num?)?.toInt() ??
          0,
        paymentMethod: (json['payment_method'] as String?) ?? 'online',
      status: OrderStatus.fromString(json['status'] as String?),
      currentLocation: currentLoc,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      readyAt: json['ready_at'] != null
          ? DateTime.parse(json['ready_at'] as String)
          : null,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
      lastSyncedFrom: json['last_synced_from'] as String?,
      pickupOtp: json['pickup_otp'] as String?,
      deliveryOtp: json['delivery_otp'] as String?,
    );
  }

  /// Convert to JSON for database updates
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'kitchen_name': restaurantName,
      'kitchen_phone': restaurantPhone,
      'user_id': userId,
      'user_name': userName,
      'user_phone': userPhone,
      'pickup_address': {
        'address': restaurantAddress,
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'delivery_address': {
        'address': userAddress,
        'lat': deliveryLocation.latitude,
        'lng': deliveryLocation.longitude,
      },
      'delivery_instructions': deliveryInstructions,
      'items': items.map((e) => e.toJson()).toList(),
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'agent_earnings': earnings,
      'estimated_distance_km': distance,
      'estimated_time_minutes': estimatedTime,
      'payment_method': paymentMethod,
      'status': status.dbValue,
      'current_location': currentLocation?.toJson(),
    };
  }
}

/// Order item model
class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String? notes;

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity:
          (json['qty'] as num?)?.toInt() ??
          (json['quantity'] as num?)?.toInt() ??
          1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'qty': quantity,
      'price': price,
      'notes': notes,
    };
  }
}

/// Delivery partner location model
class DeliveryLocation {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final DateTime updatedAt;

  DeliveryLocation({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    required this.updatedAt,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'heading': heading,
      'speed': speed,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
