import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';

/// Visual indicator showing: Kitchen → Delivery Partner → Customer
/// Animated dots/lines between steps with active step highlighted
class ConnectionFlowIndicator extends StatelessWidget {
  /// 0 = Kitchen, 1 = En Route, 2 = Customer
  final int activeStep;
  final bool compact;

  const ConnectionFlowIndicator({
    super.key,
    required this.activeStep,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 20,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.5)
            : AppColors.lightSurface,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          _buildNode(
            context,
            icon: Icons.restaurant_rounded,
            label: compact ? 'Kitchen' : 'Kitchen',
            isActive: activeStep >= 0,
            isCompleted: activeStep > 0,
            isDark: isDark,
          ),
          _buildConnector(
            context,
            isActive: activeStep >= 1,
            isDark: isDark,
          ),
          _buildNode(
            context,
            icon: Icons.delivery_dining_rounded,
            label: compact ? 'You' : 'You',
            isActive: activeStep >= 1,
            isCompleted: activeStep > 1,
            isCurrent: activeStep == 1,
            isDark: isDark,
          ),
          _buildConnector(
            context,
            isActive: activeStep >= 2,
            isDark: isDark,
          ),
          _buildNode(
            context,
            icon: Icons.person_rounded,
            label: compact ? 'Customer' : 'Customer',
            isActive: activeStep >= 2,
            isCompleted: activeStep > 2,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildNode(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    bool isCompleted = false,
    bool isCurrent = false,
  }) {
    final double size = compact ? 36 : 44;
    final Color color = isCompleted
        ? AppColors.emeraldGreen
        : isActive
            ? AppColors.emeraldGreen
            : (isDark ? AppColors.mediumGrey : AppColors.lightGrey);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppConstants.durationStandard,
            curve: AppConstants.curveStandard,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: isCurrent ? 2.5 : 1.5,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              size: compact ? 18 : 22,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.captionStyle(
              color: isActive
                  ? (isDark ? AppColors.textLight : AppColors.textPrimary)
                  : (isDark ? AppColors.mediumGrey : AppColors.textTertiary),
            ).copyWith(
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              fontSize: compact ? 10 : 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(
    BuildContext context, {
    required bool isActive,
    required bool isDark,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: _AnimatedDottedLine(
          isActive: isActive,
          isDark: isDark,
        ),
      ),
    );
  }
}

/// Animated dotted line connector between flow steps
class _AnimatedDottedLine extends StatefulWidget {
  final bool isActive;
  final bool isDark;

  const _AnimatedDottedLine({
    required this.isActive,
    required this.isDark,
  });

  @override
  State<_AnimatedDottedLine> createState() => _AnimatedDottedLineState();
}

class _AnimatedDottedLineState extends State<_AnimatedDottedLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AnimatedDottedLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedLinePainter(
        animation: _controller,
        isActive: widget.isActive,
        color: widget.isActive
            ? AppColors.emeraldGreen
            : (widget.isDark ? AppColors.mediumGrey.withValues(alpha: 0.3) : AppColors.lightGrey),
      ),
      size: const Size(double.infinity, 2),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Animation<double> animation;
  final bool isActive;
  final Color color;

  _DottedLinePainter({
    required this.animation,
    required this.isActive,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = isActive ? -(animation.value * (dashWidth + dashSpace)) : 0;

    while (startX < size.width) {
      final endX = (startX + dashWidth).clamp(0.0, size.width);
      if (startX >= 0) {
        canvas.drawLine(
          Offset(startX, size.height / 2),
          Offset(endX, size.height / 2),
          paint,
        );
      }
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) {
    return oldDelegate.isActive != isActive || oldDelegate.color != color;
  }
}
