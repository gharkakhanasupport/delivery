import 'package:flutter/material.dart';
import '../services/navigation_animation_service.dart';
import '../constants/colors.dart';

/// A widget that provides Telegram-style circular bloom animation for navigation.
/// Wrap your navigation widget with this to enable the effect.
class NavigationAnimationOverlay extends StatefulWidget {
  final Widget child;
  final Function(int pageIndex)? onNavigate;

  const NavigationAnimationOverlay({
    super.key,
    required this.child,
    this.onNavigate,
  });

  @override
  State<NavigationAnimationOverlay> createState() =>
      NavigationAnimationOverlayState();
}

class NavigationAnimationOverlayState extends State<NavigationAnimationOverlay>
    with SingleTickerProviderStateMixin {
  Offset? _animationOrigin;
  AnimationController? _animationController;
  Animation<double>? _radiusAnimation;
  Animation<double>? _fadeAnimation;
  bool _isAnimating = false;
  Color _bloomColor = AppColors.emeraldGreen;
  int? _targetPageIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Navigate to target page
        if (_targetPageIndex != null && widget.onNavigate != null) {
          widget.onNavigate!(_targetPageIndex!);
        }

        // Quick fade out
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() {
              _isAnimating = false;
              _animationOrigin = null;
              _targetPageIndex = null;
            });
          }
        });

        NavigationAnimationService.clear();
      }
    });

    // Listen for navigation bloom triggers
    NavigationAnimationService.bloomTrigger.addListener(_onBloomTrigger);
  }

  @override
  void dispose() {
    NavigationAnimationService.bloomTrigger.removeListener(_onBloomTrigger);
    _animationController?.dispose();
    super.dispose();
  }

  void _onBloomTrigger() {
    final trigger = NavigationAnimationService.bloomTrigger.value;
    if (trigger == null || _isAnimating) return;

    if (!mounted) return;

    setState(() {
      _animationOrigin = trigger.position;
      _bloomColor = trigger.color;
      _targetPageIndex = trigger.targetPageIndex;
      _isAnimating = true;
    });

    // Calculate max radius needed to cover entire screen
    final screenSize = MediaQuery.of(context).size;
    final maxRadius = _calculateMaxRadius(trigger.position, screenSize);

    _radiusAnimation = Tween<double>(begin: 0, end: maxRadius).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start bloom animation
    _animationController!.forward(from: 0);
  }

  double _calculateMaxRadius(Offset origin, Size screenSize) {
    // Find the corner farthest from the origin
    final corners = [
      Offset.zero,
      Offset(screenSize.width, 0),
      Offset(0, screenSize.height),
      Offset(screenSize.width, screenSize.height),
    ];

    double maxDistance = 0;
    for (final corner in corners) {
      final distance = (corner - origin).distance;
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }

    return maxDistance + 50;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Animated bloom overlay
        if (_isAnimating && _animationOrigin != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animationController!,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _CircularBloomPainter(
                      center: _animationOrigin!,
                      radius: _radiusAnimation!.value,
                      color: _bloomColor,
                      opacity: _fadeAnimation?.value ?? 0.6,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom painter for the circular bloom effect
class _CircularBloomPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;
  final double opacity;

  _CircularBloomPainter({
    required this.center,
    required this.radius,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;

    // Create gradient paint for the bloom effect
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        color.withValues(alpha: opacity),
        color.withValues(alpha: opacity * 0.5),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_CircularBloomPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.center != center ||
        oldDelegate.opacity != opacity;
  }
}
