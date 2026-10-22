import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/slope.dart';
import 'theme.dart';

void _text(Canvas c, String s, Offset at, TextStyle st, {TextAlign align = TextAlign.left, double anchorY = 0}) {
  final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
  var dx = at.dx;
  if (align == TextAlign.center) dx -= tp.width / 2;
  if (align == TextAlign.right) dx -= tp.width;
  tp.paint(c, Offset(dx, at.dy - tp.height * anchorY));
}

({List<double> ticks, double step}) niceTicks(double lo, double hi, int n) {
  final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
  final step0 = span / n;
  final mag = math.pow(10, (math.log(step0) / math.ln10).floor()).toDouble();
  final e = step0 / mag;
  final step = (e >= 7.5 ? 10 : e >= 3.5 ? 5 : e >= 1.5 ? 2 : 1) * mag;
  final t = <double>[];
  for (var v = (lo / step).ceil() * step; v <= hi + step * 1e-6; v += step) {
    t.add(double.parse(v.toStringAsFixed(8)));
  }
  return (ticks: t, step: step);
}

/// Class colours, gentle to steep, chosen to read on the dark band.
const List<Color> classColors = [
  Color(0xFF63C98F),
  Color(0xFF93CF68),
  Color(0xFFC8CF4C),
  Color(0xFFF2B31B),
  Color(0xFFF08A2C),
  Color(0xFFE6603C),
  Color(0xFFCF4040),
];

// ------------------------------------------------------------------ class dial

/// A clinometer-style dial. Each land slope class A–G gets an equal arc, so the
/// gentle classes are as easy to read as the steep ones. The needle springs to the value.
class ClassDial extends StatelessWidget {
  const ClassDial({super.key, required this.slope, this.height = 168});
  final double? slope;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pos = slope == null ? 0.0 : classDialPosition(slope!);
    final active = slope == null ? -1 : slopeClasses.indexOf(classOf(slope!));
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: pos),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.elasticOut,
        builder: (_, v, __) => CustomPaint(
          size: Size.infinite,
          painter: _DialPainter(v, active, p.bandInk, p.bandMuted, p.amber, slope != null),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.v, this.active, this.ink, this.muted, this.needle, this.hasValue);
  final double v;
  final int active;
  final Color ink, muted, needle;
  final bool hasValue;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height - 12);
    final r = math.min(size.width / 2 - 22, size.height - 34);
    const n = 7;
    const gap = 0.025;
    for (var i = 0; i < n; i++) {
      final a0 = math.pi + i * math.pi / n + gap / 2;
      final on = i == active;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a0,
        math.pi / n - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 16 : 10
          ..strokeCap = StrokeCap.butt
          ..color = classColors[i].withOpacity(on || !hasValue ? 1 : 0.42),
      );
      final am = a0 + (math.pi / n - gap) / 2;
      final lp = c + Offset(math.cos(am), math.sin(am)) * (r + 17);
      _text(canvas, slopeClasses[i].code, lp,
          TextStyle(fontFamily: kFont, fontSize: on ? 15 : 12, fontWeight: FontWeight.w700, color: on ? ink : muted),
          align: TextAlign.center, anchorY: 0.5);
    }
    // minor ticks inside the arc
    final tk = Paint()
      ..color = muted.withOpacity(0.6)
      ..strokeWidth = 1.2;
    for (var i = 0; i <= 28; i++) {
      final a = math.pi + i / 28 * math.pi;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r - 12), c + d * (r - (i % 4 == 0 ? 20 : 15)), tk);
    }
    // needle
    final a = math.pi + v.clamp(-0.02, 1.02) * math.pi;
    final d = Offset(math.cos(a), math.sin(a));
    final tip = c + d * (r - 6);
    final side = Offset(-d.dy, d.dx) * 4.5;
    final needlePath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(c.dx + side.dx, c.dy + side.dy)
      ..lineTo(c.dx - d.dx * 10, c.dy - d.dy * 10)
      ..lineTo(c.dx - side.dx, c.dy - side.dy)
      ..close();
    if (hasValue) {
      canvas.drawPath(needlePath.shift(const Offset(0, 2)), Paint()..color = Colors.black.withOpacity(0.25));
      canvas.drawPath(needlePath, Paint()..color = needle);
    }
    canvas.drawCircle(c, 9, Paint()..color = ink);
    canvas.drawCircle(c, 4, Paint()..color = hasValue ? needle : muted);
  }

  @override
  bool shouldRepaint(_DialPainter o) => o.v != v || o.active != active || o.ink != ink;
}

// ------------------------------------------------------------------ profile

class ProfileChart extends StatelessWidget {
  const ProfileChart({super.key, required this.result, this.height = 240});
  final SlopeResult result;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(result.rows.map((r) => r.elev.toStringAsFixed(2)).join(',')),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeInOutCubic,
        builder: (_, t, __) => CustomPaint(painter: _ProfilePainter(result, t, p)),
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.r, this.t, this.p);
  final SlopeResult r;
  final double t;
  final Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    if (!r.ok) {
      _text(canvas, 'Needs two points with elevation', size.center(Offset.zero), T.body(p.muted),
          align: TextAlign.center, anchorY: 0.5);
      return;
    }
    const L = 48.0, R = 14.0, top = 18.0, B = 30.0;
    final pw = size.width - L - R, ph = size.height - top - B;
    final ys = r.rows.map((e) => e.elev).toList();
    var y0 = ys.reduce(math.min), y1 = ys.reduce(math.max);
    final pad = math.max((y1 - y0) * 0.18, 1.0);
    y0 -= pad;
    y1 += pad;
    final x1 = math.max(r.rows.last.chainage, 1.0);
    double X(double v) => L + v / x1 * pw;
    double Y(double v) => top + (1 - (v - y0) / (y1 - y0)) * ph;
    final small = T.num(p.muted, size: 11, w: FontWeight.w500);
    final grid = Paint()
      ..color = p.line
      ..strokeWidth = 1;
    final yt = niceTicks(y0, y1, 4);
    for (final v in yt.ticks) {
      canvas.drawLine(Offset(L, Y(v)), Offset(L + pw, Y(v)), grid);
      _text(canvas, v.toStringAsFixed(yt.step < 1 ? 1 : 0), Offset(L - 6, Y(v)), small,
          align: TextAlign.right, anchorY: 0.5);
    }
    final xt = niceTicks(0, x1, 4);
    for (final v in xt.ticks) {
      _text(canvas, v.toStringAsFixed(0), Offset(X(v), top + ph + 7), small, align: TextAlign.center);
    }
    _text(canvas, 'm', Offset(L + pw, top + ph + 7), small, align: TextAlign.right);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(L, 0, pw * t + 2, size.height));
    // ground fill
    final area = Path()..moveTo(X(0), top + ph);
    for (final e in r.rows) {
      area.lineTo(X(e.chainage), Y(e.elev));
    }
    area
      ..lineTo(X(r.rows.last.chainage), top + ph)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.field.withOpacity(0.32), p.field.withOpacity(0.04)],
        ).createShader(Rect.fromLTWH(L, top, pw, ph)),
    );
    // vertical error bars
    final eb = Paint()
      ..color = p.muted.withOpacity(0.7)
      ..strokeWidth = 1.2;
    for (final e in r.rows) {
      if (e.point.hasRL) continue;
      final x = X(e.chainage);
      canvas.drawLine(Offset(x, Y(e.elev - e.sigma)), Offset(x, Y(e.elev + e.sigma)), eb);
      canvas.drawLine(Offset(x - 3, Y(e.elev - e.sigma)), Offset(x + 3, Y(e.elev - e.sigma)), eb);
      canvas.drawLine(Offset(x - 3, Y(e.elev + e.sigma)), Offset(x + 3, Y(e.elev + e.sigma)), eb);
    }
    // best-fit line, dashed
    final f = r.fit;
    if (f != null && f.a != null) {
      final dash = Paint()
        ..color = p.amber
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final a = Offset(X(0), Y(f.a!)), b = Offset(X(x1), Y(f.a! + f.b! * x1));
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var s = 0.0; s < len; s += 11) {
        canvas.drawLine(a + dir * s, a + dir * math.min(s + 6, len), dash);
      }
    }
    // profile line
    final line = Path();
    for (final (i, e) in r.rows.indexed) {
      if (i == 0) {
        line.moveTo(X(e.chainage), Y(e.elev));
      } else {
        line.lineTo(X(e.chainage), Y(e.elev));
      }
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = p.field
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();

    // stations and labels
    final every = math.max(1, (r.rows.length / (pw / 34)).ceil());
    for (final (i, e) in r.rows.indexed) {
      final o = Offset(X(e.chainage), Y(e.elev));
      if (o.dx > L + pw * t + 2) continue;
      canvas.drawCircle(o, 5, Paint()..color = p.surface);
      canvas.drawCircle(
          o,
          5,
          Paint()
            ..color = i == 0 ? p.amber : p.field
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4);
      if (i % every == 0 || i == r.rows.length - 1) {
        _text(canvas, e.point.label, Offset(o.dx.clamp(L + 10, L + pw - 10), math.max(o.dy - 9, top + 6)),
            T.num(p.ink, size: 11.5, w: FontWeight.w700),
            align: TextAlign.center, anchorY: 1);
      }
    }
    final axis = Paint()
      ..color = p.ink.withOpacity(0.7)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(L, top), Offset(L, top + ph), axis);
    canvas.drawLine(Offset(L, top + ph), Offset(L + pw, top + ph), axis);
  }

  @override
  bool shouldRepaint(_ProfilePainter o) => o.t != t || o.r != r || o.p != p;
}

// ------------------------------------------------------------------ plan view

class PlanView extends StatelessWidget {
  const PlanView({super.key, required this.points, this.height = 220});
  final List<SurveyPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _PlanPainter(points, context.pal)),
      );
}

class _PlanPainter extends CustomPainter {
  _PlanPainter(this.pts, this.p);
  final List<SurveyPoint> pts;
  final Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) {
      _text(canvas, 'Needs two points', size.center(Offset.zero), T.body(p.muted),
          align: TextAlign.center, anchorY: 0.5);
      return;
    }
    final lat0 = pts.first.lat, lon0 = pts.first.lon;
    final k = math.pi / 180 * earthRadius;
    final xy = pts
        .map((q) => Offset((q.lon - lon0) * k * math.cos(lat0 * math.pi / 180), (q.lat - lat0) * k))
        .toList();
    final minx = xy.map((e) => e.dx).reduce(math.min), maxx = xy.map((e) => e.dx).reduce(math.max);
    final miny = xy.map((e) => e.dy).reduce(math.min), maxy = xy.map((e) => e.dy).reduce(math.max);
    const m = 34.0;
    final sc = math.min((size.width - 2 * m) / math.max(maxx - minx, 1), (size.height - 2 * m) / math.max(maxy - miny, 1));
    final ox = (size.width - (maxx - minx) * sc) / 2, oy = (size.height - (maxy - miny) * sc) / 2;
    Offset P(Offset q) => Offset(ox + (q.dx - minx) * sc, size.height - oy - (q.dy - miny) * sc);

    // faint graticule
    final g = Paint()
      ..color = p.line.withOpacity(0.7)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), g);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    final path = Path();
    for (final (i, q) in xy.indexed) {
      final o = P(q);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = p.field
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round);
    for (final (i, q) in xy.indexed) {
      final o = P(q);
      canvas.drawCircle(o, i == 0 ? 6.5 : 4.5, Paint()..color = i == 0 ? p.amber : p.surface);
      canvas.drawCircle(
          o,
          i == 0 ? 6.5 : 4.5,
          Paint()
            ..color = p.field
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      final right = o.dx + 8 < size.width - 30;
      _text(canvas, pts[i].label, Offset(right ? o.dx + 8 : o.dx - 8, o.dy - 8), T.num(p.ink, size: 11.5, w: FontWeight.w700),
          align: right ? TextAlign.left : TextAlign.right, anchorY: 0.5);
    }
    // north arrow
    final na = Offset(size.width - 20, 14);
    final arrow = Path()
      ..moveTo(na.dx, na.dy)
      ..lineTo(na.dx - 6, na.dy + 14)
      ..lineTo(na.dx, na.dy + 10)
      ..lineTo(na.dx + 6, na.dy + 14)
      ..close();
    canvas.drawPath(arrow, Paint()..color = p.ink);
    _text(canvas, 'N', Offset(na.dx, na.dy + 17), T.num(p.ink, size: 11, w: FontWeight.w700), align: TextAlign.center);
    // scale bar
    final target = (size.width * 0.28) / sc;
    final st = niceTicks(0, target, 1).step;
    final len = st * sc;
    final sb = Paint()
      ..color = p.muted
      ..strokeWidth = 2;
    final y = size.height - 12;
    canvas.drawLine(Offset(12, y), Offset(12 + len, y), sb);
    canvas.drawLine(Offset(12, y - 4), Offset(12, y + 4), sb);
    canvas.drawLine(Offset(12 + len, y - 4), Offset(12 + len, y + 4), sb);
    _text(canvas, st >= 1000 ? '${(st / 1000).toStringAsFixed(st % 1000 == 0 ? 0 : 1)} km' : '${st.toStringAsFixed(st < 1 ? 1 : 0)} m',
        Offset(14, y - 5), T.num(p.muted, size: 11, w: FontWeight.w500),
        anchorY: 1);
  }

  @override
  bool shouldRepaint(_PlanPainter o) => o.pts != pts || o.p != p;
}

// ------------------------------------------------------------------ sparkline

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.result, this.width = 72, this.height = 34});
  final SlopeResult result;
  final double width, height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _SparkPainter(result, context.pal)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.r, this.p);
  final SlopeResult r;
  final Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    if (!r.ok) {
      canvas.drawLine(Offset(4, size.height / 2), Offset(size.width - 4, size.height / 2),
          Paint()
            ..color = p.line
            ..strokeWidth = 2);
      return;
    }
    final ys = r.rows.map((e) => e.elev).toList();
    final y0 = ys.reduce(math.min), y1 = ys.reduce(math.max);
    final x1 = math.max(r.rows.last.chainage, 1.0);
    final span = math.max(y1 - y0, 0.5);
    Offset P(ProfileRow e) =>
        Offset(3 + e.chainage / x1 * (size.width - 6), 3 + (1 - (e.elev - y0) / span) * (size.height - 6));
    final area = Path()..moveTo(3, size.height);
    final line = Path();
    for (final (i, e) in r.rows.indexed) {
      final o = P(e);
      area.lineTo(o.dx, o.dy);
      if (i == 0) {
        line.moveTo(o.dx, o.dy);
      } else {
        line.lineTo(o.dx, o.dy);
      }
    }
    area
      ..lineTo(size.width - 3, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = p.fieldSoft);
    canvas.drawPath(
        line,
        Paint()
          ..color = p.field
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(P(r.rows.first), 2.6, Paint()..color = p.amber);
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.r != r || o.p != p;
}
