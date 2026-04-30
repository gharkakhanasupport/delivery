import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Shimmer loading placeholder widget
/// Provides skeleton loading states that match each screen's layout
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
    this.isCircle = false,
  });

  /// Creates a text-line shimmer placeholder
  factory ShimmerLoading.text({
    Key? key,
    double width = 120,
    double height = 14,
  }) {
    return ShimmerLoading(
      key: key,
      width: width,
      height: height,
      borderRadius: 6,
    );
  }

  /// Creates a card shimmer placeholder
  factory ShimmerLoading.card({
    Key? key,
    double height = 120,
  }) {
    return ShimmerLoading(
      key: key,
      height: height,
      borderRadius: 16,
    );
  }

  /// Creates a circle shimmer placeholder (avatars)
  factory ShimmerLoading.circle({
    Key? key,
    double size = 48,
  }) {
    return ShimmerLoading(
      key: key,
      width: size,
      height: size,
      isCircle: true,
    );
  }

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBaseLight;
    final highlightColor =
        isDark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlightLight;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built shimmer layouts for common screens
class ShimmerLayouts {
  /// Order card shimmer skeleton
  static Widget orderCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerLoading.circle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading.text(width: 150, height: 16),
                    const SizedBox(height: 8),
                    ShimmerLoading.text(width: 100, height: 12),
                  ],
                ),
              ),
              ShimmerLoading.text(width: 60, height: 24),
            ],
          ),
          const SizedBox(height: 16),
          const ShimmerLoading(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ShimmerLoading.text(width: 80, height: 12)),
              const SizedBox(width: 12),
              Expanded(child: ShimmerLoading.text(width: 80, height: 12)),
            ],
          ),
        ],
      ),
    );
  }

  /// Earnings section shimmer skeleton
  static Widget earningsCard() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(height: 120, borderRadius: 20),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ShimmerLoading(height: 80, borderRadius: 12)),
              SizedBox(width: 12),
              Expanded(child: ShimmerLoading(height: 80, borderRadius: 12)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ShimmerLoading(height: 80, borderRadius: 12)),
              SizedBox(width: 12),
              Expanded(child: ShimmerLoading(height: 80, borderRadius: 12)),
            ],
          ),
        ],
      ),
    );
  }

  /// Profile section shimmer skeleton
  static Widget profileHeader() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          ShimmerLoading(height: 140, borderRadius: 20),
          SizedBox(height: 20),
          ShimmerLoading(height: 60, borderRadius: 12),
          SizedBox(height: 12),
          ShimmerLoading(height: 60, borderRadius: 12),
          SizedBox(height: 12),
          ShimmerLoading(height: 60, borderRadius: 12),
        ],
      ),
    );
  }
}
