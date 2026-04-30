import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart';

/// Custom painter for a top-view 3D delivery bike/scooter
/// Creates a bird's-eye view of a delivery rider on a scooter
class DeliveryBikePainter extends CustomPainter {
  final double heading; // Rotation angle in degrees (0 = north)
  final Color primaryColor;
  final Color shadowColor;

  DeliveryBikePainter({
    this.heading = 0,
    this.primaryColor = AppColors.emeraldGreen,
    Color? shadowColor,
  }) : shadowColor = shadowColor ?? Colors.black.withValues(alpha: 0.3);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 50; // Base design is 50x50

    // Rotate canvas based on heading
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((heading * math.pi) / 180);
    canvas.translate(-center.dx, -center.dy);

    // === DROP SHADOW ===
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Shadow ellipse (offset down-right for 3D effect)
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(2 * scale, 3 * scale),
        width: 28 * scale,
        height: 18 * scale,
      ),
      shadowPaint,
    );

    // === SCOOTER BODY ===
    final bodyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [primaryColor, Color.lerp(primaryColor, Colors.black, 0.3)!],
    );

    final bodyPaint = Paint()
      ..shader = bodyGradient.createShader(
        Rect.fromCenter(center: center, width: 24 * scale, height: 36 * scale),
      );

    // Main scooter body (elongated oval)
    final bodyPath = Path();
    bodyPath.addOval(
      Rect.fromCenter(center: center, width: 18 * scale, height: 32 * scale),
    );
    canvas.drawPath(bodyPath, bodyPaint);

    // === WHEELS ===
    final wheelPaint = Paint()..color = const Color(0xFF2C2C2C);
    final wheelHighlight = Paint()..color = const Color(0xFF4A4A4A);

    // Front wheel
    canvas.drawOval(
      Rect.fromCenter(
        center: center - Offset(0, 14 * scale),
        width: 10 * scale,
        height: 6 * scale,
      ),
      wheelPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center - Offset(0, 14.5 * scale),
        width: 6 * scale,
        height: 3 * scale,
      ),
      wheelHighlight,
    );

    // Rear wheel
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, 12 * scale),
        width: 12 * scale,
        height: 7 * scale,
      ),
      wheelPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, 11.5 * scale),
        width: 7 * scale,
        height: 3.5 * scale,
      ),
      wheelHighlight,
    );

    // === DELIVERY BOX ===
    final boxGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.goldenMustard,
        Color.lerp(AppColors.goldenMustard, Colors.orange, 0.3)!,
      ],
    );

    final boxPaint = Paint()
      ..shader = boxGradient.createShader(
        Rect.fromCenter(
          center: center + Offset(0, 6 * scale),
          width: 14 * scale,
          height: 12 * scale,
        ),
      );

    // Delivery box on the back
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center + Offset(0, 6 * scale),
        width: 14 * scale,
        height: 12 * scale,
      ),
      Radius.circular(2 * scale),
    );
    canvas.drawRRect(boxRect, boxPaint);

    // Box lid line
    final lidPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1 * scale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      center + Offset(-6 * scale, 2 * scale),
      center + Offset(6 * scale, 2 * scale),
      lidPaint,
    );

    // === RIDER/HELMET ===
    // Helmet (oval from above)
    final helmetGradient = RadialGradient(
      colors: [Colors.white, const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)],
      stops: const [0.0, 0.6, 1.0],
    );

    final helmetPaint = Paint()
      ..shader = helmetGradient.createShader(
        Rect.fromCenter(
          center: center - Offset(0, 6 * scale),
          width: 12 * scale,
          height: 10 * scale,
        ),
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: center - Offset(0, 6 * scale),
        width: 12 * scale,
        height: 10 * scale,
      ),
      helmetPaint,
    );

    // Helmet visor/front (dark strip)
    final visorPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawArc(
      Rect.fromCenter(
        center: center - Offset(0, 6 * scale),
        width: 12 * scale,
        height: 10 * scale,
      ),
      -math.pi * 0.7,
      math.pi * 0.4,
      false,
      visorPaint
        ..strokeWidth = 2.5 * scale
        ..style = PaintingStyle.stroke,
    );

    // === HANDLEBARS ===
    final handlePaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;

    // Left handlebar
    canvas.drawLine(
      center + Offset(-8 * scale, -10 * scale),
      center + Offset(-12 * scale, -8 * scale),
      handlePaint,
    );

    // Right handlebar
    canvas.drawLine(
      center + Offset(8 * scale, -10 * scale),
      center + Offset(12 * scale, -8 * scale),
      handlePaint,
    );

    // === DIRECTION INDICATOR (small arrow at front) ===
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    arrowPath.moveTo(center.dx, center.dy - 18 * scale);
    arrowPath.lineTo(center.dx - 3 * scale, center.dy - 14 * scale);
    arrowPath.lineTo(center.dx + 3 * scale, center.dy - 14 * scale);
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DeliveryBikePainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.primaryColor != primaryColor;
  }
}

/// Widget wrapper for DeliveryBikePainter
class DeliveryBikeMarker extends StatelessWidget {
  final double size;
  final double heading;
  final Color? primaryColor;

  const DeliveryBikeMarker({
    super.key,
    this.size = 50,
    this.heading = 0,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DeliveryBikePainter(
          heading: heading,
          primaryColor: primaryColor ?? AppColors.emeraldGreen,
        ),
      ),
    );
  }
}
