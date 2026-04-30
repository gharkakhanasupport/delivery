import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../models/order.dart';
import '../widgets/slide_to_online_bar.dart';
import '../widgets/order_bottom_sheet.dart';
import '../widgets/openstreetmap_widget.dart';
import 'delivery_navigation_screen.dart';
import '../services/online_service.dart';
import '../services/order_service.dart';
import '../utils/app_dialogs.dart';

/// Screen 1: Radar Map (Redesigned) — Fully Realtime
class RadarMapScreen extends StatefulWidget {
  const RadarMapScreen({super.key});

  @override
  State<RadarMapScreen> createState() => _RadarMapScreenState();
}

class _RadarMapScreenState extends State<RadarMapScreen> {
  bool _showOrdersList = false;
  List<Order> _orders = [];

  /// Supabase realtime channel for new available orders
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _fetchInitialOrders();
    _subscribeToNewOrders();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  /// Initial fetch of available orders
  Future<void> _fetchInitialOrders() async {
    final orders = await OrderService.fetchAvailableOrders();
    if (mounted) {
      setState(() => _orders = orders);
    }
  }

  /// Subscribe to realtime order inserts/updates
  void _subscribeToNewOrders() {
    final client = Supabase.instance.client;
    _ordersChannel = client
        .channel('radar-available-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          callback: (payload) {
            // Re-fetch orders on any change to the delivery_orders table
            _fetchInitialOrders();
          },
        )
        .subscribe();
  }


  void _goOnline() {
    OnlineService.goOnline();
    setState(() {
      _showOrdersList = false; // Reset to "Scanning" state
    });
  }

  void _navigateToDelivery(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryNavigationScreen(order: order),
      ),
    ).then((_) {
      // Returned from delivery
    });
  }

  void _showOrderBottomSheet(Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) => OrderBottomSheet(
        order: order,
        onAccept: () async {
          Navigator.pop(bottomSheetContext);
          // Show loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
          final ok = await OrderService.acceptOrder(order.id);
          if (!mounted) return;
          Navigator.pop(context); // close loader
          if (ok) {
            _navigateToDelivery(order);
          } else {
            AppDialogs.showError(
              context,
              'Could not accept order — another partner may have taken it.',
            );
            _fetchInitialOrders();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: OnlineService.isOnline,
      builder: (context, isOnline, child) {
        return Scaffold(
          backgroundColor:
              isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
          body: Stack(
            children: [
              // FULL SCREEN MAP
              Positioned.fill(
                child: OpenStreetMapWidget(
                  orders: isOnline ? _orders : [],
                  onOrderTap: () {
                    if (_orders.isNotEmpty) {
                      _showOrderBottomSheet(_orders[0]);
                    }
                  },
                  controlsBottomOffset: 250,
                ),
              ),

              // Gradient Overlay for Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Header Controls
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Online Status Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? AppColors.emeraldGreen.withValues(alpha: 0.9)
                            : AppColors.darkCard.withValues(alpha: 0.9),
                        borderRadius: AppConstants.borderRadiusCircular,
                        boxShadow: [
                          BoxShadow(
                            color: isOnline
                                ? AppColors.emeraldGreen
                                    .withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.white
                                  : AppColors.mediumGrey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: AppTypography.captionStyle(
                              color: isOnline
                                  ? Colors.white
                                  : AppColors.lightGrey,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Power Button
                    if (isOnline)
                      GestureDetector(
                        onTap: () =>
                            AppDialogs.showOfflineConfirmation(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.darkCard.withValues(alpha: 0.9),
                            borderRadius: AppConstants.borderRadiusMedium,
                            border: Border.all(
                              color: AppColors.error,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.error.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.power_settings_new_rounded,
                            color: AppColors.error,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // BOTTOM ACTION AREA
              if (!isOnline)
                _buildOfflineView(isDark)
              else if (_showOrdersList)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: _buildOrderList(isDark),
                )
              else
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 30,
                  child: _buildFindOrdersView(isDark),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineView(bool isDark) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You are Offline',
                style: AppTypography.headingStyle(
                  color: isDark
                      ? AppColors.textLightSecondary
                      : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Go online to start receiving orders',
                style: AppTypography.bodyStyle(
                  color: isDark
                      ? AppColors.textLightSecondary
                      : AppColors.textSecondary,
                  size: 14,
                ),
              ),
              const SizedBox(height: 16),
              SlideToOnlineBar(onSlideComplete: _goOnline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindOrdersView(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.95),
        borderRadius: AppConstants.borderRadiusXL,
        border: Border.all(
          color: AppColors.emeraldGreen.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withValues(alpha: 0.1),
              borderRadius: AppConstants.borderRadiusMedium,
            ),
            child: const Icon(
              Icons.radar_rounded,
              color: AppColors.emeraldGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Scanning for orders...",
                  style: AppTypography.bodyStyle(
                    color: Colors.white,
                    weight: FontWeight.w600,
                    size: 15,
                  ),
                ),
                Text(
                  "Current scan radius: 5 km",
                  style: AppTypography.captionStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                borderRadius: AppConstants.borderRadiusMedium,
              ),
              child: ElevatedButton(
                onPressed: () => setState(() => _showOrdersList = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppConstants.borderRadiusMedium,
                  ),
                ),
                child: Text(
                  "View List",
                  style: AppTypography.captionStyle(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // List Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Orders (${_orders.length})',
                    style: AppTypography.headingStyle(
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  Text(
                    'Nearby Delivery Requests',
                    style: AppTypography.captionStyle(
                      color: isDark
                          ? AppColors.textLightSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark
                      ? AppColors.textLightSecondary
                      : AppColors.mediumGrey,
                ),
                label: Text(
                  "Minimize",
                  style: AppTypography.captionStyle(
                    color: isDark
                        ? AppColors.textLightSecondary
                        : AppColors.mediumGrey,
                  ),
                ),
                onPressed: () => setState(() => _showOrdersList = false),
              ),
            ],
          ),
        ),

        // Scrollable List
        Expanded(
          child: Container(
            color: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return _buildOrderCard(order, isDark);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Order order, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: AppConstants.borderRadiusLarge,
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showOrderBottomSheet(order),
            borderRadius: AppConstants.borderRadiusLarge,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header: Restaurant Name & Earnings
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldGreen
                              .withValues(alpha: 0.08),
                          borderRadius: AppConstants.borderRadiusMedium,
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: AppColors.emeraldGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          order.restaurantName,
                          style: AppTypography.bodyStyle(
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                            weight: FontWeight.w600,
                            size: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          borderRadius: AppConstants.borderRadiusCircular,
                        ),
                        child: Text(
                          '₹${order.earnings.toInt()}',
                          style: AppTypography.captionStyle(
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Source -> Destination Visual
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 10,
                            color: AppColors.emeraldGreen,
                          ),
                          Container(
                            width: 1.5,
                            height: 22,
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderSubtle,
                          ),
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppColors.goldenMustard,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.restaurantAddress,
                              style: AppTypography.bodyStyle(
                                color: isDark
                                    ? AppColors.textLightSecondary
                                    : AppColors.textSecondary,
                                size: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              order.userAddress,
                              style: AppTypography.bodyStyle(
                                color: isDark
                                    ? AppColors.textLightSecondary
                                    : AppColors.textSecondary,
                                size: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderSubtle,
                  ),
                  const SizedBox(height: 12),

                  // Footer: Distance/Time & Accept Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.route_rounded,
                            size: 15,
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.mediumGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${order.distance} km',
                            style: AppTypography.captionStyle(
                              color: isDark
                                  ? AppColors.textLightSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.mediumGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${order.estimatedTime} mins',
                            style: AppTypography.captionStyle(
                              color: isDark
                                  ? AppColors.textLightSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 32,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.primaryGradient,
                            ),
                            borderRadius: AppConstants.borderRadiusMedium,
                          ),
                          child: ElevatedButton(
                            onPressed: () => _navigateToDelivery(order),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppConstants.borderRadiusMedium,
                              ),
                            ),
                            child: Text(
                              'Accept',
                              style: AppTypography.captionStyle(
                                color: Colors.white,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
