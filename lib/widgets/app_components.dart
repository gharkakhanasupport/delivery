import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';

/// Reusable UI components following High-Contrast Material Design
/// All components optimized for driver use with fat-finger friendly touch targets

// =============================================================================
// PRIMARY BUTTON
// Solid Cobalt Blue, white text, 8px corner radius, 56px height
// =============================================================================

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryAction,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryAction.withValues(
            alpha: 0.5,
          ),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// SECONDARY BUTTON
// White background, Blue border, Blue text
// =============================================================================

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: AppConstants.buttonHeight,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryAction,
          side: BorderSide(
            color: isLoading
                ? AppColors.primaryAction.withValues(alpha: 0.5)
                : AppColors.primaryAction,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryAction.withValues(alpha: 0.5),
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// STATUS BADGE
// Small rounded pills for order status display
// [ NEW ] - Blue, [ PICKING UP ] - Orange, [ DELIVERED ] - Green
// =============================================================================

enum OrderStatusType { newOrder, pickingUp, enRoute, delivered, cancelled }

class StatusBadge extends StatelessWidget {
  final OrderStatusType status;
  final String? customLabel;

  const StatusBadge({super.key, required this.status, this.customLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        customLabel ?? _getLabel(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.w600,
          letterSpacing: AppTypography.letterSpacingLabels,
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (status) {
      case OrderStatusType.newOrder:
        return AppColors.badgeNew;
      case OrderStatusType.pickingUp:
        return AppColors.badgePickingUp;
      case OrderStatusType.enRoute:
        return AppColors.badgePickingUp;
      case OrderStatusType.delivered:
        return AppColors.badgeDelivered;
      case OrderStatusType.cancelled:
        return AppColors.badgeCancelled;
    }
  }

  String _getLabel() {
    switch (status) {
      case OrderStatusType.newOrder:
        return 'NEW';
      case OrderStatusType.pickingUp:
        return 'PICKING UP';
      case OrderStatusType.enRoute:
        return 'EN ROUTE';
      case OrderStatusType.delivered:
        return 'DELIVERED';
      case OrderStatusType.cancelled:
        return 'CANCELLED';
    }
  }
}

// =============================================================================
// ORDER CARD
// Clean card with 1px border, left icon, right details
// =============================================================================

class OrderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String distance;
  final String pay;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? statusBadge;

  const OrderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.distance,
    required this.pay,
    this.onTap,
    this.trailing,
    this.statusBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppColors.cardBorder, width: 1),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Left-side icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryAction.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryAction, size: 24),
            ),
            const SizedBox(width: 12),
            // Center content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (statusBadge != null) ...[
                    statusBadge!,
                    const SizedBox(height: 6),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.hcTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTypography.bodySmall,
                      color: isDark
                          ? AppColors.lightGrey
                          : AppColors.hcTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right-side details
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pay,
                  style: TextStyle(
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.bold,
                    color: AppColors.successOnline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  distance,
                  style: TextStyle(
                    fontSize: AppTypography.bodySmall,
                    color: isDark
                        ? AppColors.lightGrey
                        : AppColors.hcTextSecondary,
                  ),
                ),
              ],
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.lightGrey : AppColors.hcTextSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// STAT BOX
// Large number in center, small label at bottom (for 2x2 Profile grid)
// =============================================================================

class StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  const StatBox({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: iconColor ?? AppColors.primaryAction),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: AppTypography.headline,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.hcTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.label,
              color: isDark ? AppColors.lightGrey : AppColors.hcTextSecondary,
              letterSpacing: AppTypography.letterSpacingWide,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SUMMARY BOX
// For earnings dashboard - Today, This Week, Total Balance
// =============================================================================

class SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const SummaryBox({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppColors.cardBorder, width: 1),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: valueColor ?? AppColors.primaryAction,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
                color:
                    valueColor ??
                    (isDark ? Colors.white : AppColors.hcTextPrimary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.label,
                color: isDark ? AppColors.lightGrey : AppColors.hcTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
