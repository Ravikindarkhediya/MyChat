
// Custom painter for animated background particles
import 'package:flutter/material.dart';

class ParticlesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Draw some subtle floating particles
    for (int i = 0; i < 20; i++) {
      final double x = (i * 50.0) % size.width;
      final double y = (i * 30.0) % size.height;
      final double opacity = (0.1 + (i % 3) * 0.05);

      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(
        Offset(x, y),
        1.5 + (i % 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;}