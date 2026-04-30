import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../widgets/shimmer_loading.dart';
import 'delivery_navigation_screen.dart';

/// Current Orders Screen - Active deliveries with realtime updates
class CurrentOrdersScreen extends StatefulWidget {
  const CurrentOrdersScreen({super.key});

  @override
  State<CurrentOrdersScreen> createState() => _CurrentOrdersScreenState();
}

class _CurrentOrdersScreenState extends State<CurrentOrdersScreen> {
  List<Order> _orders = [];
  bool _isLoading = false;

  /// Supabase realtime channel for order updates
  RealtimeChannel? _orderUpdatesChannel;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _subscribeToOrderUpdates();
  }

  @override
  void dispose() {
    _orderUpdatesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final orders = await OrderService.fetchActiveOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  /// Subscribe to realtime updates for orders assigned to this agent
  void _subscribeToOrderUpdates() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _orderUpdatesChannel = Supabase.instance.client
        .channel('active-order-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'delivery_partner_id',
            value: userId,
          ),
          callback: (payload) {
            // Re-fetch whenever any of our orders change
            _loadOrders();
          },
        )
        .subscribe();
  }

  void _navigateToDelivery(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryNavigationScreen(order: order),
      ),
    ).then((_) {
      _loadOrders();
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.responsivePadding(context),
                16,
                AppConstants.responsivePadding(context),
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Active Deliveries',
                      style: AppTypography.headingStyle(
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  // Refresh button
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard
                          : AppColors.lightSurface,
                      borderRadius: AppConstants.borderRadiusMedium,
                    ),
                    child: IconButton(
                      onPressed: _loadOrders,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      tooltip: 'Refresh',
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _isLoading
                  ? _buildShimmerList()
                  : _orders.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _loadOrders,
                          color: AppColors.emeraldGreen,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppConstants.responsivePadding(context),
                              vertical: 8,
                            ),
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              return _buildOrderCard(order, isDark);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerLoading.card(height: 180),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.emeraldGreen.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 56,
                color: AppColors.emeraldGreen.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No active deliveries',
              style: AppTypography.titleStyle(
                color: isDark
                    ? AppColors.textLightSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accept orders from the Home screen\nto start delivering',
              textAlign: TextAlign.center,
              style: AppTypography.bodyStyle(
                color: isDark
                    ? AppColors.textLightSecondary
                    : AppColors.textTertiary,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order, bool isDark) {
    final statusColor = _getStatusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDelivery(order),
          borderRadius: AppConstants.borderRadiusLarge,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Restaurant + Status + Earnings
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.1),
                        borderRadius: AppConstants.borderRadiusMedium,
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.emeraldGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
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
                          const SizedBox(height: 4),
                          // Status pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: AppConstants.borderRadiusCircular,
                            ),
                            child: Text(
                              order.status.label,
                              style: AppTypography.captionStyle(
                                color: statusColor,
                                weight: FontWeight.w600,
                              ).copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Earnings badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldenMustard.withValues(alpha: 0.1),
                        borderRadius: AppConstants.borderRadiusCircular,
                      ),
                      child: Text(
                        '₹${order.earnings.toInt()}',
                        style: AppTypography.bodyStyle(
                          color: AppColors.goldenMustard,
                          weight: FontWeight.w700,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Divider
                Container(
                  height: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
                ),
                const SizedBox(height: 14),

                // Address
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.textLightSecondary
                          : AppColors.mediumGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
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
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Distance and Time
                Row(
                  children: [
                    _buildMiniChip(
                      Icons.route_rounded,
                      '${order.distance} km',
                      isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildMiniChip(
                      Icons.schedule_rounded,
                      '${order.estimatedTime} min',
                      isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Navigate Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      borderRadius: AppConstants.borderRadiusMedium,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldGreen.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToDelivery(order),
                      icon: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        'Navigate',
                        style: AppTypography.bodyStyle(
                          color: Colors.white,
                          weight: FontWeight.w600,
                          size: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppConstants.borderRadiusMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.5)
            : AppColors.lightSurface,
        borderRadius: AppConstants.borderRadiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark
                ? AppColors.textLightSecondary
                : AppColors.mediumGrey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.captionStyle(
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.badgeNew;
      case OrderStatus.confirmed:
        return AppColors.badgePickingUp;
      case OrderStatus.preparing:
        return AppColors.badgePickingUp;
      case OrderStatus.readyForPickup:
        return AppColors.emeraldGreen;
      case OrderStatus.assigned:
        return AppColors.badgePickingUp;
      case OrderStatus.pickedUp:
        return AppColors.emeraldGreen;
      case OrderStatus.outForDelivery:
        return AppColors.badgeEnRoute;
      case OrderStatus.delivered:
        return AppColors.badgeDelivered;
      case OrderStatus.cancelled:
        return AppColors.badgeCancelled;
    }
  }
}
