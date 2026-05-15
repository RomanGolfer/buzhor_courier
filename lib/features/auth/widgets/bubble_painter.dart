import 'package:flutter/material.dart';
import 'package:buzhor_courier/shared/models/bubble.dart';

class BubblePainter extends CustomPainter {
  final List<Bubble> bubbles;
  BubblePainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final paint = Paint()
        ..color = const Color(0xFF5BB8F5).withValues(alpha: b.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(
        Offset(b.x * size.width, b.y * size.height),
        b.size,
        paint,
      );

      final innerPaint = Paint()
        ..color = const Color(0xFF5BB8F5).withValues(alpha: b.opacity * 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(b.x * size.width, b.y * size.height),
        b.size,
        innerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter old) => true;
}
