import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The dark instrument band at the top of each screen, with topographic contour
/// lines of a hill drawn behind the content. Every fifth line is an index contour.
class Band extends StatefulWidget {
  const Band({super.key, required this.child, this.hillAt = const Alignment(0.95, -0.6)});
  final Widget child;
  final Alignment hillAt;

  @override
  State<Band> createState() => _BandState();
}

class _BandState extends State<Band> with SingleTickerProviderStateMixin {
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void initState() {
    super.initState();
    if (Motion.ambient) _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        color: p.band,
        child: CustomPaint(
          painter: ContourPainter(color: p.contour, label: p.bandMuted, phase: _drift, hillAt: widget.hillAt),
          child: widget.child,
        ),
      ),
    );
  }
}

class ContourPainter extends CustomPainter {
  ContourPainter({required this.color, required this.label, required this.phase, required this.hillAt})
      : super(repaint: phase);
  final Color color;
  final Color label;
  final Animation<double> phase;
  final Alignment hillAt;

  @override
  void paint(Canvas canvas, Size size) {
    final c = hillAt.alongSize(size);
    final ph = phase.value * 2 * math.pi;
    final maxR = math.sqrt(size.width * size.width + size.height * size.height);
    const step = 17.0;
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = color.withOpacity(0.75);
    final thick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = color;
    for (var k = 1; k * step < maxR * 1.1; k++) {
      final base = k * step;
      final path = Path();
      const n = 96;
      for (var i = 0; i <= n; i++) {
        final th = i / n * 2 * math.pi;
        // lumpier further out, like a real hillside
        final w = 0.10 + math.min(k, 12) * 0.012;
        final r = base *
            (1 +
                w * math.sin(3 * th + 0.35 * k + ph) +
                0.6 * w * math.sin(5 * th - 0.2 * k - ph * 0.5) +
                0.3 * w * math.cos(2 * th + 0.5 * k));
        final o = Offset(c.dx + r * math.cos(th) * 1.25, c.dy + r * math.sin(th) * 0.9);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      path.close();
      canvas.drawPath(path, k % 5 == 0 ? thick : thin);
    }
    // summit marker
    canvas.drawCircle(c, 2.4, Paint()..color = label.withOpacity(0.5));
  }

  @override
  bool shouldRepaint(ContourPainter old) => old.color != color || old.hillAt != hillAt;
}
