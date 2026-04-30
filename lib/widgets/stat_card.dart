import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';

/// Premium stat card widget for earnings dashboard
/// Features subtle gradient background, animated icon, and value display
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double? valueFontSize;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueFontSize,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with colored circle background
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: AppConstants.borderRadiusMedium,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.captionStyle(
                    color: isDark
                        ? AppColors.textLightSecondary
                        : AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Value
          Text(
            value,
            style: AppTypography.headingStyle(
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
              size: valueFontSize ?? 24,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Label
          Text(
            label,
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
    );
  }
}
