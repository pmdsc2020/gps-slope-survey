import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/gps.dart';
import 'logo.dart';
import 'theme.dart';

enum NavGlyph { survey, result, surveys }

/// Bottom-bar icon that plays a short animation each time it becomes selected.
class NavIcon extends StatefulWidget {
  const NavIcon({super.key, required this.glyph, required this.selected, required this.color, this.size = 26});
  final NavGlyph glyph;
  final bool selected;
  final Color color;
  final double size;

  @override
  State<NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<NavIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 750), value: 1);

  @override
  void didUpdateWidget(NavIcon old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _NavPainter(widget.glyph, _c.value, widget.selected, widget.color),
          ),
        ),
      );
}

class _NavPainter extends CustomPainter {
  _NavPainter(this.glyph, this.v, this.selected, this.color);
  final NavGlyph glyph;
  final double v;
  final bool selected;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    switch (glyph) {
      case NavGlyph.survey:
        // pin hops and lands, sending a ripple out at its foot
        final hop = selected ? -4.5 * math.sin(math.pi * Curves.easeOut.transform(v)) : 0.0;
        if (selected && v < 1) {
          final rv = Curves.easeOut.transform(v);
          canvas.drawOval(
            Rect.fromCenter(center: const Offset(12, 21), width: 4 + 16 * rv, height: 1.6 + 4 * rv),
            Paint()
              ..color = color.withOpacity((1 - rv) * 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        }
        canvas.drawOval(Rect.fromCenter(center: const Offset(12, 21), width: 7, height: 1.8),
            Paint()..color = color.withOpacity(0.35));
        canvas.save();
        canvas.translate(0, hop);
        final pin = LogoPainter.pinPath(const Offset(12, 20.2), h: 17.5, r: 6.2);
        canvas.drawPath(pin, selected ? fill : stroke);
        canvas.drawCircle(const Offset(12, 8.9), 2.3,
            selected ? (Paint()..color = _hole(color)) : (Paint()..color = color));
        canvas.restore();
      case NavGlyph.result:
        // the slope tilts up to its angle, with the angle arc following
        final e = selected ? Curves.elasticOut.transform(v) : 1.0;
        final rise = 3 + 10 * e;
        const a = Offset(3, 19.5);
        final top = Offset(21, 19.5 - rise);
        final tri = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(21, 19.5)
          ..lineTo(top.dx, top.dy)
          ..close();
        if (selected) canvas.drawPath(tri, Paint()..color = color.withOpacity(0.25));
        canvas.drawPath(tri, stroke);
        final ang = math.atan2(a.dy - top.dy, top.dx - a.dx);
        canvas.drawArc(Rect.fromCircle(center: a, radius: 7), 0, -ang, false, stroke..strokeWidth = 1.6);
        canvas.drawCircle(top, selected ? 2.4 : 1.8, fill);
      case NavGlyph.surveys:
        // field sheets fan out
        final f = selected ? Curves.easeOutBack.transform(v) : 0.0;
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(12, 20);
          canvas.rotate((i - 1) * 0.22 * f);
          canvas.translate(-12, -20);
          final r = RRect.fromRectAndRadius(Rect.fromLTWH(6.5 + (1 - i) * 1.4, 4 + i * 1.2, 11, 15), const Radius.circular(2.4));
          if (i == 2 && selected) {
            canvas.drawRRect(r, fill);
            final ln = Paint()
              ..color = _hole(color)
              ..strokeWidth = 1.5
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(Offset(r.left + 3, r.top + 5), Offset(r.right - 3, r.top + 5), ln);
            canvas.drawLine(Offset(r.left + 3, r.top + 8.5), Offset(r.right - 4.5, r.top + 8.5), ln);
          } else {
            canvas.drawRRect(r, Paint()..color = selected ? _hole(color) : Colors.transparent);
            canvas.drawRRect(r, stroke..strokeWidth = 1.6);
          }
          canvas.restore();
        }
    }
  }

  Color _hole(Color c) => c.computeLuminance() > 0.5 ? const Color(0xFF15201A) : const Color(0xFFF2B31B);

  @override
  bool shouldRepaint(_NavPainter o) => o.v != v || o.selected != selected || o.color != color || o.glyph != glyph;
}

/// Radar-style GPS status: rings pulse out while searching; steady colour once fixed.
class GpsRadar extends StatefulWidget {
  const GpsRadar({super.key, required this.state, required this.quality, this.size = 44});
  final GpsState state;
  final FixQuality? quality;
  final double size;

  @override
  State<GpsRadar> createState() => _GpsRadarState();
}

class _GpsRadarState extends State<GpsRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  bool get _live =>
      widget.state == GpsState.searching || widget.state == GpsState.starting || widget.state == GpsState.fix;

  void _sync() {
    if (_live && Motion.ambient) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0.35;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(GpsRadar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final Color col = switch (widget.state) {
      GpsState.off => p.bandMuted,
      GpsState.error => p.bandBad,
      GpsState.starting || GpsState.searching => p.amber,
      GpsState.fix => switch (widget.quality) {
          FixQuality.good => p.bandGood,
          FixQuality.fair => p.bandWarn,
          _ => p.bandBad,
        },
    };
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _RadarPainter(_c.value, col, widget.state),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.v, this.color, this.state);
  final double v;
  final Color color;
  final GpsState state;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // fixed reticle
    canvas.drawCircle(c, R * 0.92, ring..color = color.withOpacity(0.35));
    final tick = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * R * 0.78,
          c + Offset(math.cos(a), math.sin(a)) * R * 0.98, tick);
    }
    if (state == GpsState.searching || state == GpsState.starting || state == GpsState.fix) {
      final waves = state == GpsState.fix ? 1 : 2;
      for (var k = 0; k < waves; k++) {
        final t = (v + k / waves) % 1.0;
        canvas.drawCircle(c, R * (0.18 + 0.72 * t), ring..color = color.withOpacity((1 - t) * 0.9));
      }
      if (state != GpsState.fix) {
        // sweeping beam while searching
        final sweep = Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: math.pi / 2,
            colors: [color.withOpacity(0), color.withOpacity(0.45)],
            transform: GradientRotation(v * 2 * math.pi),
          ).createShader(Rect.fromCircle(center: c, radius: R * 0.9));
        canvas.drawCircle(c, R * 0.9, sweep);
      }
    }
    if (state == GpsState.off) {
      canvas.drawLine(c + Offset(-R * 0.45, R * 0.45), c + Offset(R * 0.45, -R * 0.45),
          tick..color = color.withOpacity(0.8));
    }
    final dot = state == GpsState.fix ? 0.2 : 0.15 + 0.04 * math.sin(v * 2 * math.pi);
    canvas.drawCircle(c, R * dot, Paint()..color = color);
    if (state == GpsState.error) {
      canvas.drawCircle(c, R * 0.92, ring..color = color);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter o) => o.v != v || o.color != color || o.state != state;
}

/// Sun / moon toggle that cycles System → Light → Dark.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key, required this.mode, required this.onChanged, required this.color});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final next = switch (mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    final icon = switch (mode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
    };
    final label = switch (mode) {
      ThemeMode.system => 'Theme follows phone',
      ThemeMode.light => 'Light theme',
      ThemeMode.dark => 'Dark theme',
    };
    return IconButton(
      tooltip: label,
      onPressed: () => onChanged(next),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, a) => RotationTransition(
          turns: Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
          child: ScaleTransition(scale: a, child: child),
        ),
        child: Icon(icon, key: ValueKey(mode), color: color),
      ),
    );
  }
}

/// A check mark that draws itself.
class CheckPainter extends CustomPainter {
  CheckPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.27, w * 0.53)
      ..lineTo(w * 0.43, w * 0.69)
      ..lineTo(w * 0.75, w * 0.35);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(CheckPainter o) => o.t != t || o.color != color;
}
