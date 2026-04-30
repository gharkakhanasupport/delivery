import 'package:flutter/material.dart';
import 'dart:ui';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../models/order.dart';
import 'connection_flow_indicator.dart';

/// Bottom sheet displaying order details with premium design
/// Shows kitchen → delivery → customer connection flow
class OrderBottomSheet extends StatelessWidget {
  final Order order;
  final VoidCallback onAccept;

  const OrderBottomSheet({
    super.key,
    required this.order,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.97)
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.mediumGrey.withValues(alpha: 0.4)
                          : AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // New Order badge + Order number
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.badgeNew.withValues(alpha: 0.12),
                        borderRadius: AppConstants.borderRadiusCircular,
                        border: Border.all(
                          color: AppColors.badgeNew.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'NEW ORDER',
                        style: AppTypography.labelStyle(
                          color: AppColors.badgeNew,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '#${order.orderNumber}',
                      style: AppTypography.captionStyle(
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Restaurant info
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
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.restaurantName,
                            style: AppTypography.titleStyle(
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.restaurantAddress,
                            style: AppTypography.captionStyle(
                              color: isDark
                                  ? AppColors.textLightSecondary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Connection flow indicator (Kitchen → You → Customer)
                const ConnectionFlowIndicator(
                  activeStep: 0,
                  compact: true,
                ),
                const SizedBox(height: 16),

                // Delivery address
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface.withValues(alpha: 0.5)
                        : AppColors.lightSurface,
                    borderRadius: AppConstants.borderRadiusMedium,
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: AppColors.accentOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deliver to',
                              style: AppTypography.captionStyle(
                                color: isDark
                                    ? AppColors.textLightSecondary
                                    : AppColors.textTertiary,
                              ),
                            ),
                            Text(
                              order.userAddress,
                              style: AppTypography.bodyStyle(
                                color: isDark
                                    ? AppColors.textLight
                                    : AppColors.textPrimary,
                                size: 13,
                                weight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.route_rounded,
                      value: '${order.distance.toStringAsFixed(1)} km',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.schedule_rounded,
                      value: '${order.estimatedTime} min',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.currency_rupee_rounded,
                      value: '₹${order.earnings.toInt()}',
                      isDark: isDark,
                      highlight: true,
                    ),
                    if (order.items.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildStatChip(
                        icon: Icons.shopping_bag_outlined,
                        value: '${order.items.length} items',
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Accept button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      borderRadius: AppConstants.borderRadiusLarge,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldGreen.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppConstants.borderRadiusLarge,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Accept Order',
                            style: AppTypography.bodyStyle(
                              color: Colors.white,
                              weight: FontWeight.w700,
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required bool isDark,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.goldenMustard.withValues(alpha: 0.1)
              : (isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.5)
                  : AppColors.lightSurface),
          borderRadius: AppConstants.borderRadiusMedium,
          border: Border.all(
            color: highlight
                ? AppColors.goldenMustard.withValues(alpha: 0.3)
                : (isDark ? AppColors.borderDark : AppColors.borderSubtle),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: highlight
                  ? AppColors.goldenMustard
                  : AppColors.emeraldGreen,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.bodyStyle(
                size: 13,
                weight: FontWeight.w700,
                color: highlight
                    ? AppColors.goldenMustard
                    : (isDark ? AppColors.textLight : AppColors.textPrimary),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
