import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app mark, drawn with the same 108-unit geometry as brand/make_logo.py.
/// [t] runs the build-up animation: 0 = empty tile, 1 = finished logo.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 40, this.t = 1, this.rounded = true});
  final double size;
  final double t;
  final bool rounded;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: LogoPainter(t: t, rounded: rounded)),
      );
}

class LogoPainter extends CustomPainter {
  LogoPainter({this.t = 1, this.rounded = true});
  final double t;
  final bool rounded;

  static const forest = Color(0xFF0E3B2C);
  static const field = Color(0xFF1E6A4D);
  static const contour = Color(0xFF3F8A69);
  static const ground = Color(0xFFEAF2EA);
  static const amber = Color(0xFFF2B31B);
  static const ink = Color(0xFF0E3B2C);

  static const a = Offset(26, 77), b = Offset(81, 77), c = Offset(81, 45);

  static Offset onSlope(double f) => Offset(a.dx + (c.dx - a.dx) * f, a.dy + (c.dy - a.dy) * f);

  static double _seg(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

  static Path pinPath(Offset tip, {double h = 26, double r = 9.2}) {
    final cy = tip.dy - h + r;
    final d = h - r;
    final ang = math.asin(r / d);
    final tx = r * math.cos(ang), ty = cy + r * math.sin(ang);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - tx, ty)
      ..arcToPoint(Offset(tip.dx + tx, ty), radius: Radius.circular(r), largeArc: true, clockwise: true)
      ..close();
  }

  static List<Path> contourPaths() => [
        Path()
          ..moveTo(-4, 40)
          ..cubicTo(18, 30, 34, 34, 52, 26)
          ..cubicTo(70, 18, 88, 14, 112, 20),
        Path()
          ..moveTo(-4, 58)
          ..cubicTo(16, 50, 34, 52, 50, 44)
          ..cubicTo(66, 36, 86, 30, 112, 36),
        Path()
          ..moveTo(-4, 92)
          ..cubicTo(20, 86, 44, 92, 64, 84)
          ..cubicTo(84, 76, 96, 76, 112, 80),
        Path()
          ..moveTo(-4, 104)
          ..cubicTo(24, 100, 50, 106, 72, 99)
          ..cubicTo(94, 92, 100, 94, 112, 96),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 108;
    canvas.save();
    canvas.scale(s);
    final tile = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 108, 108), Radius.circular(rounded ? 24 : 0));
    canvas.clipRRect(tile);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 108, 108),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [field, forest],
        ).createShader(const Rect.fromLTWH(0, 0, 108, 108)),
    );
    // contours draw in
    final ct = _seg(t, 0, 0.35);
    if (ct > 0) {
      final pc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = contour.withOpacity(0.55);
      for (final p in contourPaths()) {
        for (final m in p.computeMetrics()) {
          canvas.drawPath(m.extractPath(0, m.length * ct), pc);
        }
      }
    }
    // art, enlarged slightly like the launcher icon
    canvas.translate(54, 54);
    canvas.scale(1.18);
    canvas.translate(-54, -54);

    // ground rises from the foot of the slope
    final gt = Curves.easeOutCubic.transform(_seg(t, 0.15, 0.55));
    if (gt > 0) {
      final top = Offset(c.dx, b.dy + (c.dy - b.dy) * gt);
      final tri = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(top.dx, top.dy)
        ..close();
      canvas.drawPath(tri, Paint()..color = ground);
      // angle sector
      final ang = math.atan2(a.dy - top.dy, top.dx - a.dx);
      const r = 17.0;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..arcTo(Rect.fromCircle(center: a, radius: r), 0, -ang, false)
          ..close(),
        Paint()..color = amber,
      );
    }
    // survey points pop in
    for (final (i, f) in [0.42, 0.61].indexed) {
      final pt = Curves.easeOutBack.transform(_seg(t, 0.45 + i * 0.08, 0.62 + i * 0.08));
      if (pt <= 0) continue;
      final o = onSlope(f);
      canvas.drawCircle(o, 3.4 * pt, Paint()..color = ink);
      canvas.drawCircle(o, 1.4 * pt, Paint()..color = ground);
    }
    // pin drops onto the slope
    final dt = _seg(t, 0.62, 1.0);
    if (dt > 0) {
      final drop = Curves.bounceOut.transform(dt);
      final tip = onSlope(0.8);
      final dy = (1 - drop) * -40;
      canvas.save();
      canvas.translate(0, dy);
      final pin = pinPath(tip);
      canvas.drawPath(pin, Paint()..color = amber);
      canvas.drawPath(
        pin,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(Offset(tip.dx, tip.dy - 26 + 9.2), 3.4, Paint()..color = ink);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.t != t || old.rounded != rounded;
}
