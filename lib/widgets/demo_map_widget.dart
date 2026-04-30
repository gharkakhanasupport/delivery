import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/order.dart';

/// Demo map widget that works without Google Maps API
/// Incorporates InteractiveViewer for pan/zoom capabilities
class DemoMapWidget extends StatefulWidget {
  final List<Order> orders;
  final VoidCallback? onOrderTap;

  const DemoMapWidget({super.key, required this.orders, this.onOrderTap});

  @override
  State<DemoMapWidget> createState() => _DemoMapWidgetState();
}

class _DemoMapWidgetState extends State<DemoMapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TransformationController _transformationController =
      TransformationController();
  bool _initialized = false;
  static const double _mapSize = 2000.0; // Large map area for panning

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Initialize view to center of the map
        if (!_initialized) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          // Center the 2000x2000 map in the viewport
          final x = (width - _mapSize) / 2;
          final y = (height - _mapSize) / 2;
          _transformationController.value = Matrix4.identity()
            ..setTranslationRaw(x, y, 0);
          _initialized = true;
        }

        return InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(1000), // Infinite-ish scroll
          minScale: 0.5,
          maxScale: 4.0,
          constrained: false, // Let the child be its own size
          child: Container(
            width: _mapSize,
            height: _mapSize,
            color: AppColors.deepNavy,
            child: Stack(
              children: [
                // Grid background
                Positioned.fill(child: CustomPaint(painter: GridPainter())),

                // Animated radar circles (Center)
                Center(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(400, 400),
                        painter: RadarPainter(_animationController.value),
                      );
                    },
                  ),
                ),

                // User location (Center)
                Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),

                // Order markers
                ...widget.orders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final order = entry.value;
                  return _buildOrderMarker(context, order, index);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderMarker(BuildContext context, Order order, int index) {
    // Position markers relative to the center of the MAP (not screen)
    const centerX = _mapSize / 2;
    const centerY = _mapSize / 2;

    // Position markers in a circle around center
    final angle = (index * 2 * pi / widget.orders.length);
    const radius = 180.0; // Increased radius for better spacing
    final x = centerX + cos(angle) * radius;
    final y = centerY + sin(angle) * radius;

    return Positioned(
      left: x - 30,
      top: y - 40,
      child: GestureDetector(
        onTap: widget.onOrderTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Earnings badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.goldenMustard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldenMustard.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '₹${order.earnings.toInt()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Marker pin
            const Icon(
              Icons.location_on,
              color: AppColors.goldenMustard,
              size: 32,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter for grid background
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.emeraldGreen.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const gridSize = 50.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for animated radar circles
class RadarPainter extends CustomPainter {
  final double animationValue;

  RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw 3 concentric circles with pulse animation
    for (int i = 1; i <= 3; i++) {
      final radius = (size.width / 6) * i;
      final opacity = (1 - animationValue) * 0.3;

      final paint = Paint()
        ..color = AppColors.emeraldGreen.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius + (animationValue * 20), paint);
    }

    // Draw filled circle at center
    final centerPaint = Paint()
      ..color = AppColors.emeraldGreen.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 30, centerPaint);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}
