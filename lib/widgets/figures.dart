import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Body-type silhouette — same paths as web BodyFigure (viewBox 120x220).
class BodyFigure extends StatelessWidget {
  const BodyFigure({super.key, required this.width, required this.active, this.height = 150});
  final double width;
  final bool active;
  final double height;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: active ? C.jade : C.sage),
      duration: const Duration(milliseconds: 300),
      builder: (_, color, _) => SizedBox(
        height: height,
        width: height * 120 / 220,
        child: CustomPaint(painter: _BodyPainter(width, active, color ?? C.sage)),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.w, this.active, this.color);
  final double w;
  final bool active;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 220);
    const cx = 60.0;
    final torso = 22 * w;
    final hip = 20 * w;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: active ? 0.95 : 0.55), color.withValues(alpha: active ? 0.75 : 0.35)],
      ).createShader(const Rect.fromLTWH(0, 0, 120, 220));
    canvas.drawCircle(const Offset(cx, 24), 15, paint);
    final body = Path()
      ..moveTo(cx - torso, 50)
      ..quadraticBezierTo(cx, 42, cx + torso, 50)
      ..lineTo(cx + torso + 2 * w, 96)
      ..quadraticBezierTo(cx + hip + 4, 112, cx + hip, 120)
      ..lineTo(cx - hip, 120)
      ..quadraticBezierTo(cx - hip - 4, 112, cx - torso - 2 * w, 96)
      ..close();
    final armL = Path()
      ..moveTo(cx - torso - 1, 52)
      ..quadraticBezierTo(cx - torso - 12 * w, 80, cx - torso - 10 * w, 118)
      ..lineTo(cx - torso - 3 * w, 119)
      ..quadraticBezierTo(cx - torso - 2, 86, cx - torso + 6, 64)
      ..close();
    final armR = Path()
      ..moveTo(cx + torso + 1, 52)
      ..quadraticBezierTo(cx + torso + 12 * w, 80, cx + torso + 10 * w, 118)
      ..lineTo(cx + torso + 3 * w, 119)
      ..quadraticBezierTo(cx + torso + 2, 86, cx + torso - 6, 64)
      ..close();
    final legL = Path()
      ..moveTo(cx - hip, 118)
      ..lineTo(cx - 2, 118)
      ..lineTo(cx - 5, 206)
      ..quadraticBezierTo(cx - 11, 210, cx - 15 - 2 * w, 206)
      ..close();
    final legR = Path()
      ..moveTo(cx + hip, 118)
      ..lineTo(cx + 2, 118)
      ..lineTo(cx + 5, 206)
      ..quadraticBezierTo(cx + 11, 210, cx + 15 + 2 * w, 206)
      ..close();
    for (final p in [body, armL, armR, legL, legR]) {
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter o) => o.color != color || o.w != w || o.active != active;
}

/// Tappable target-zone figure — same shapes as web ZonesFigure.
class ZonesFigure extends StatelessWidget {
  const ZonesFigure({super.key, required this.selected, required this.onToggle});
  final List<String> selected;
  final ValueChanged<String> onToggle;

  static final Map<String, Path> zones = {
    'neck': Path()
      ..moveTo(38, 44)
      ..quadraticBezierTo(60, 34, 82, 44)
      ..lineTo(84, 58)
      ..quadraticBezierTo(60, 52, 36, 58)
      ..close(),
    'arms': Path()
      ..moveTo(30, 54)
      ..quadraticBezierTo(18, 84, 20, 118)
      ..lineTo(28, 119)
      ..quadraticBezierTo(30, 88, 38, 64)
      ..close()
      ..moveTo(90, 54)
      ..quadraticBezierTo(102, 84, 100, 118)
      ..lineTo(92, 119)
      ..quadraticBezierTo(90, 88, 82, 64)
      ..close(),
    'back': Path()
      ..moveTo(40, 60)
      ..lineTo(80, 60)
      ..lineTo(82, 84)
      ..lineTo(38, 84)
      ..close(),
    'core': Path()
      ..moveTo(39, 86)
      ..lineTo(81, 86)
      ..lineTo(82, 100)
      ..quadraticBezierTo(60, 106, 38, 100)
      ..close(),
    'hips': Path()
      ..moveTo(38, 102)
      ..quadraticBezierTo(60, 108, 82, 102)
      ..lineTo(84, 122)
      ..lineTo(36, 122)
      ..close(),
    'legs': Path()
      ..moveTo(38, 124)
      ..lineTo(58, 124)
      ..lineTo(55, 206)
      ..quadraticBezierTo(49, 210, 43, 206)
      ..close()
      ..moveTo(82, 124)
      ..lineTo(62, 124)
      ..lineTo(65, 206)
      ..quadraticBezierTo(71, 210, 77, 206)
      ..close(),
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final scale = (c.maxHeight / 220).clamp(0.0, c.maxWidth / 120);
      final dx = (c.maxWidth - 120 * scale) / 2;
      return GestureDetector(
        onTapUp: (d) {
          final local = Offset((d.localPosition.dx - dx) / scale, d.localPosition.dy / scale);
          for (final e in zones.entries) {
            if (e.value.contains(local)) {
              onToggle(e.key);
              return;
            }
          }
        },
        child: CustomPaint(size: Size(c.maxWidth, c.maxHeight), painter: _ZonesPainter(selected, scale, dx)),
      );
    });
  }
}

class _ZonesPainter extends CustomPainter {
  _ZonesPainter(this.selected, this.scale, this.dx);
  final List<String> selected;
  final double scale, dx;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(dx, 0);
    canvas.scale(scale);
    final base = Paint()..color = C.sandDeep;
    canvas.drawCircle(const Offset(60, 24), 15, base);
    canvas.drawPath(
      Path()
        ..moveTo(38, 50)
        ..quadraticBezierTo(60, 42, 82, 50)
        ..lineTo(84, 96)
        ..quadraticBezierTo(84, 112, 80, 120)
        ..lineTo(40, 120)
        ..quadraticBezierTo(36, 112, 36, 96)
        ..close(),
      base,
    );
    canvas.drawPath(
      Path()
        ..moveTo(37, 52)
        ..quadraticBezierTo(26, 80, 28, 118)
        ..lineTo(35, 119)
        ..quadraticBezierTo(38, 86, 44, 64)
        ..close(),
      base,
    );
    canvas.drawPath(
      Path()
        ..moveTo(83, 52)
        ..quadraticBezierTo(94, 80, 92, 118)
        ..lineTo(85, 119)
        ..quadraticBezierTo(82, 86, 76, 64)
        ..close(),
      base,
    );
    canvas.drawPath(
      Path()
        ..moveTo(40, 118)
        ..lineTo(58, 118)
        ..lineTo(55, 206)
        ..quadraticBezierTo(49, 210, 43, 206)
        ..close(),
      base,
    );
    canvas.drawPath(
      Path()
        ..moveTo(80, 118)
        ..lineTo(62, 118)
        ..lineTo(65, 206)
        ..quadraticBezierTo(71, 210, 77, 206)
        ..close(),
      base,
    );
    final on = Paint()..color = C.jade.withValues(alpha: 0.8);
    for (final e in ZonesFigure.zones.entries) {
      if (selected.contains(e.key)) canvas.drawPath(e.value, on);
    }
  }

  @override
  bool shouldRepaint(covariant _ZonesPainter o) => o.selected.join() != selected.join();
}
