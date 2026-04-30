import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';

/// Animated status badge pill widget
/// Shows order statuses, online/offline states with pulsing dot animations
class StatusBadge extends StatefulWidget {
  final String label;
  final Color color;
  final bool showPulse;
  final bool isSmall;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.showPulse = false,
    this.isSmall = false,
    this.icon,
  });

  /// Online status badge with pulsing green dot
  factory StatusBadge.online() {
    return const StatusBadge(
      label: 'ONLINE',
      color: AppColors.statusOnline,
      showPulse: true,
    );
  }

  /// Offline status badge
  factory StatusBadge.offline() {
    return const StatusBadge(
      label: 'OFFLINE',
      color: AppColors.statusOffline,
    );
  }

  /// Busy status badge with pulsing yellow dot
  factory StatusBadge.busy() {
    return const StatusBadge(
      label: 'BUSY',
      color: AppColors.statusBusy,
      showPulse: true,
    );
  }

  /// Order status badge from OrderStatus
  factory StatusBadge.orderStatus(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = AppColors.orderPending;
        break;
      case 'confirmed':
      case 'preparing':
        color = AppColors.badgePickingUp;
        break;
      case 'ready_for_pickup':
      case 'assigned':
        color = AppColors.badgeNew;
        break;
      case 'picked_up':
      case 'out_for_delivery':
        color = AppColors.badgeEnRoute;
        break;
      case 'delivered':
        color = AppColors.badgeDelivered;
        break;
      case 'cancelled':
        color = AppColors.badgeCancelled;
        break;
      default:
        color = AppColors.mediumGrey;
    }
    return StatusBadge(
      label: status.toUpperCase().replaceAll('_', ' '),
      color: color,
      showPulse: status == 'out_for_delivery' || status == 'picked_up',
      isSmall: true,
    );
  }

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.showPulse && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.isSmall ? 10.0 : 11.0;
    final hPadding = widget.isSmall ? 8.0 : 12.0;
    final vPadding = widget.isSmall ? 4.0 : 6.0;
    final dotSize = widget.isSmall ? 6.0 : 8.0;

    return AnimatedContainer(
      duration: AppConstants.durationStandard,
      curve: AppConstants.curveStandard,
      padding: EdgeInsets.symmetric(
        horizontal: hPadding,
        vertical: vPadding,
      ),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 14, color: widget.color),
            const SizedBox(width: 4),
          ] else if (widget.showPulse) ...[
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: _pulseAnimation.value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(
                          alpha: _pulseAnimation.value * 0.5,
                        ),
                        blurRadius: dotSize,
                        spreadRadius: dotSize * 0.3 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: widget.color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
