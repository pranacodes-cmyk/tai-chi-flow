import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Falling confetti burst (web `Confetti`).
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.height = 360});
  final double height;
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_c.value * 3.6, widget.height),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.h);
  final double t, h;
  static const colors = [C.jade, C.gold, C.terracotta, C.sage];
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 28; i++) {
      final dur = 2.2 + (i % 5) * 0.25;
      final delay = (i % 7) * 0.08;
      final p = ((t - delay) / dur).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final e = Curves.easeOut.transform(p);
      final x = size.width * ((i * 37) % 100) / 100;
      final y = -20 + (h + 20) * e;
      final rot = (360 + i * 20) * e * math.pi / 180;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      final paint = Paint()..color = colors[i % 4].withValues(alpha: 1 - p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -5, 6, 10),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter o) => o.t != t;
}
