import 'package:flutter/material.dart';

/// The official Spendo Geometric Isometric Logo.
/// Exact 100x100 vector specification:
/// - Top Path: points="38,16 78,16 64,34 24,34" (#EAB308)
/// - Mid Path: points="24,34 45,34 76,66 55,66" (#00A86B)
/// - Bottom Path: points="36,66 76,66 62,84 22,84" (#F3F4F6)
class SpendoLogo extends StatelessWidget {
  final double size;
  final bool showBackground;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final Color? topColor;
  final Color? greenColor;
  final Color? bottomColor;

  const SpendoLogo({
    super.key,
    this.size = 40,
    this.showBackground = true,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.topColor,
    this.greenColor,
    this.bottomColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _SpendoLogoPainter(
          showBackground: showBackground,
          borderRadius: borderRadius,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          borderWidth: borderWidth,
          topColor: topColor,
          greenColor: greenColor,
          bottomColor: bottomColor,
        ),
      ),
    );
  }
}

class _SpendoLogoPainter extends CustomPainter {
  final bool showBackground;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final Color? topColor;
  final Color? greenColor;
  final Color? bottomColor;

  _SpendoLogoPainter({
    required this.showBackground,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.topColor,
    this.greenColor,
    this.bottomColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Scale coordinate space from 100x100 to target widget size
    final scale = size.width / 100.0;
    canvas.scale(scale, scale);

    // 1. Background Squircle
    if (showBackground) {
      final bgPaint = Paint()
        ..color = backgroundColor ?? const Color(0xFF09090B)
        ..style = PaintingStyle.fill;
      final radius = borderRadius != null ? (borderRadius! / scale) : 22.0;
      final bgRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        Radius.circular(radius),
      );
      canvas.drawRRect(bgRRect, bgPaint);

      if (borderColor != null) {
        final borderPaint = Paint()
          ..color = borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = (borderWidth ?? 1.0) / scale;
        canvas.drawRRect(bgRRect, borderPaint);
      }
    }

    final yellowPaint = Paint()
      ..color = topColor ?? const Color(0xFFFFD600)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final greenPaint = Paint()
      ..color = greenColor ?? const Color(0xFF0F766E)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final whitePaint = Paint()
      ..color = bottomColor ?? const Color(0xFFF3F4F6)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 2. Top Segment: Yellow #EAB308 (المصروف والوقود)
    // points="38,16 78,16 64,34 24,34"
    final path1 = Path()
      ..moveTo(38, 16)
      ..lineTo(78, 16)
      ..lineTo(64, 34)
      ..lineTo(24, 34)
      ..close();
    canvas.drawPath(path1, yellowPaint);

    // 3. Middle Diagonal Bridge: Green #00A86B (سجل العمل والإنتاج)
    // points="24,34 45,34 76,66 55,66"
    final path2 = Path()
      ..moveTo(24, 34)
      ..lineTo(45, 34)
      ..lineTo(76, 66)
      ..lineTo(55, 66)
      ..close();
    canvas.drawPath(path2, greenPaint);

    // 4. Bottom Segment: White #F3F4F6 (الاستقرار والميزان المالي)
    // points="36,66 76,66 62,84 22,84"
    final path3 = Path()
      ..moveTo(36, 66)
      ..lineTo(76, 66)
      ..lineTo(62, 84)
      ..lineTo(22, 84)
      ..close();
    canvas.drawPath(path3, whitePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpendoLogoPainter oldDelegate) {
    return oldDelegate.showBackground != showBackground ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.topColor != topColor ||
        oldDelegate.greenColor != greenColor ||
        oldDelegate.bottomColor != bottomColor;
  }
}
