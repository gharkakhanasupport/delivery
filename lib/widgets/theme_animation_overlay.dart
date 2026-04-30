import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/theme_service.dart';

/// A widget that provides Telegram-style circular reveal animation for theme transitions.
/// Wrap your MaterialApp with this widget to enable the effect.
class ThemeAnimationOverlay extends StatefulWidget {
  final Widget child;

  const ThemeAnimationOverlay({super.key, required this.child});

  @override
  State<ThemeAnimationOverlay> createState() => _ThemeAnimationOverlayState();
}

class _ThemeAnimationOverlayState extends State<ThemeAnimationOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  ui.Image? _capturedImage;
  Offset? _animationOrigin;
  AnimationController? _animationController;
  Animation<double>? _radiusAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
          _capturedImage?.dispose();
          _capturedImage = null;
          _animationOrigin = null;
        });
      }
    });

    // Listen for theme animation triggers
    ThemeService.animationTrigger.addListener(_onAnimationTrigger);
  }

  @override
  void dispose() {
    ThemeService.animationTrigger.removeListener(_onAnimationTrigger);
    _animationController?.dispose();
    _capturedImage?.dispose();
    super.dispose();
  }

  void _onAnimationTrigger() async {
    final trigger = ThemeService.animationTrigger.value;
    if (trigger == null) return;

    // Capture current screen
    await _captureScreen();

    if (_capturedImage == null) {
      // Fallback: just toggle without animation
      ThemeService.toggleTheme();
      return;
    }

    if (!mounted) return;

    setState(() {
      _animationOrigin = trigger;
      _isAnimating = true;
    });

    // Calculate max radius needed to cover entire screen
    final screenSize = MediaQuery.of(context).size;
    final maxRadius = _calculateMaxRadius(trigger, screenSize);

    _radiusAnimation = Tween<double>(begin: 0, end: maxRadius).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Toggle theme immediately (new theme shows underneath)
    ThemeService.toggleTheme();

    // Start reveal animation
    _animationController!.forward(from: 0);

    // Clear the trigger
    ThemeService.animationTrigger.value = null;
  }

  Future<void> _captureScreen() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 1.0);
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      debugPrint('Failed to capture screen: $e');
    }
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

    return maxDistance + 50; // Add padding
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // Main app content wrapped in RepaintBoundary for capturing
          RepaintBoundary(key: _repaintKey, child: widget.child),

          // Animated overlay showing old theme being "cut away"
          if (_isAnimating &&
              _capturedImage != null &&
              _animationOrigin != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animationController!,
                builder: (context, child) {
                  return ClipPath(
                    clipper: _CircularRevealClipper(
                      center: _animationOrigin!,
                      radius: _radiusAnimation!.value,
                      inverted: true, // Clip outside the circle
                    ),
                    child: RawImage(
                      image: _capturedImage,
                      fit: BoxFit.cover,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom clipper that creates a circular clip path
class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  final bool inverted;

  _CircularRevealClipper({
    required this.center,
    required this.radius,
    this.inverted = false,
  });

  @override
  Path getClip(Size size) {
    final path = Path();

    if (inverted) {
      // Draw full screen rect, then cut out circle
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      path.addOval(Rect.fromCircle(center: center, radius: radius));
      path.fillType = PathFillType.evenOdd;
    } else {
      path.addOval(Rect.fromCircle(center: center, radius: radius));
    }

    return path;
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
