import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size canvasSize;

  static const List<Color> _boxColors = [
    Color(0xFF6C63FF),
    Color(0xFF3ECFCF),
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFFFF9F43),
  ];

  BoundingBoxPainter({required this.objects, required this.canvasSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final color = _boxColors[i % _boxColors.length];
      _drawBox(canvas, size, obj, color);
    }
  }

  void _drawBox(Canvas canvas, Size size, DetectedObject obj, Color color) {
    final rect = Rect.fromLTWH(
      obj.x * size.width,
      obj.y * size.height,
      obj.width * size.width,
      obj.height * size.height,
    );

    // Glowing outer border
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)), glowPaint);

    // Main border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    // Corner brackets (top-left)
    _drawCornerBracket(canvas, rect.topLeft, color, true, true);
    _drawCornerBracket(canvas, rect.topRight, color, false, true);
    _drawCornerBracket(canvas, rect.bottomLeft, color, true, false);
    _drawCornerBracket(canvas, rect.bottomRight, color, false, false);

    // Label background
    final label = '${obj.displayLabel}  ${obj.confidencePercent}';
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final labelPadH = 10.0;
    final labelPadV = 6.0;
    final labelW = textPainter.width + labelPadH * 2;
    final labelH = textPainter.height + labelPadV * 2;
    final labelY = (rect.top - labelH - 4).clamp(0, size.height - labelH);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH( rect.left.toDouble(), labelY.toDouble(), labelW.toDouble(), labelH.toDouble(),
),
      const Radius.circular(6),
    );

    final bgPaint = Paint()..color = color.withOpacity(0.9);
    canvas.drawRRect(bgRect, bgPaint);

    textPainter.paint(
        canvas, Offset(rect.left + labelPadH, labelY + labelPadV));
  }

  void _drawCornerBracket(
      Canvas canvas, Offset corner, Color color, bool isLeft, bool isTop) {
    const len = 16.0;
    const width = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final xDir = isLeft ? 1.0 : -1.0;
    final yDir = isTop ? 1.0 : -1.0;

    canvas.drawLine(corner, corner + Offset(xDir * len, 0), paint);
    canvas.drawLine(corner, corner + Offset(0, yDir * len), paint);
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) =>
      oldDelegate.objects != objects;
}
