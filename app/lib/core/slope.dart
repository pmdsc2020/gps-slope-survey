import 'dart:math' as math;

import 'models.dart';

const double earthRadius = 6371008.8;

double _rad(double d) => d * math.pi / 180;

/// Horizontal (great-circle) distance in metres.
double haversine(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1), dLon = _rad(lon2 - lon1);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h.toDouble())));
}

double distBetween(SurveyPoint a, SurveyPoint b) => haversine(a.lat, a.lon, b.lat, b.lon);

class ProfileRow {
  ProfileRow(this.point, this.chainage, this.dist, this.dh, this.slope, this.elev, this.sigma);
  final SurveyPoint point;
  final double chainage; // m from first point, along the route
  final double dist; // m from previous point (0 for first)
  final double? dh; // m from previous point
  final double? slope; // % from previous point
  final double elev;
  final double sigma;
}

enum Method { e2e, fit, route }

extension MethodLabel on Method {
  String get label => switch (this) {
        Method.e2e => 'End to end',
        Method.fit => 'Best fit',
        Method.route => 'Along route',
      };
  String get short => switch (this) {
        Method.e2e => 'End to end',
        Method.fit => 'Best fit',
        Method.route => 'Route',
      };
}

class SlopeFigure {
  SlopeFigure({
    required this.method,
    required this.dist,
    required this.dh,
    required this.slope,
    required this.unc,
    this.a,
    this.b,
    this.r2,
  });
  final Method method;
  final double dist; // horizontal distance used, m
  final double dh; // height difference, m (negative = fall)
  final double? slope; // %, signed
  final double? unc; // ± %, one sigma
  final double? a; // best-fit intercept
  final double? b; // best-fit gradient (m/m)
  final double? r2;
}

class SlopeResult {
  SlopeResult(this.rows, this.skipped, {this.e2e, this.route, this.fit});
  final List<ProfileRow> rows;
  final int skipped; // points without elevation
  final SlopeFigure? e2e;
  final SlopeFigure? route;
  final SlopeFigure? fit;

  int get n => rows.length;
  bool get ok => rows.length >= 2;

  SlopeFigure? by(Method m) => switch (m) {
        Method.e2e => e2e,
        Method.fit => fit ?? e2e,
        Method.route => route,
      };

  List<SlopeFigure> get all => [e2e, fit, route].whereType<SlopeFigure>().toList();
}

SlopeResult computeSlope(List<SurveyPoint> pts) {
  final v = pts.where((p) => p.elevation != null && p.lat.isFinite && p.lon.isFinite).toList();
  final rows = <ProfileRow>[];
  var ch = 0.0;
  for (var i = 0; i < v.length; i++) {
    final p = v[i];
    var d = 0.0;
    double? dh, s;
    if (i > 0) {
      d = distBetween(v[i - 1], p);
      ch += d;
      dh = p.elevation! - v[i - 1].elevation!;
      s = d > 0 ? dh / d * 100 : null;
    }
    rows.add(ProfileRow(p, ch, d, dh, s, p.elevation!, p.sigma));
  }
  final skipped = pts.length - v.length;
  if (v.length < 2) return SlopeResult(rows, skipped);

  final first = v.first, last = v.last;
  final dH = last.elevation! - first.elevation!;
  final dEnd = distBetween(first, last);
  final u2 = math.sqrt(first.sigma * first.sigma + last.sigma * last.sigma);
  final e2e = SlopeFigure(
    method: Method.e2e,
    dist: dEnd,
    dh: dH,
    slope: dEnd > 0 ? dH / dEnd * 100 : null,
    unc: dEnd > 0 ? u2 / dEnd * 100 : null,
  );
  final route = SlopeFigure(
    method: Method.route,
    dist: ch,
    dh: dH,
    slope: ch > 0 ? dH / ch * 100 : null,
    unc: ch > 0 ? u2 / ch * 100 : null,
  );
  SlopeFigure? fit;
  if (v.length >= 3) {
    final n = rows.length;
    final mx = rows.fold<double>(0, (t, r) => t + r.chainage) / n;
    final my = rows.fold<double>(0, (t, r) => t + r.elev) / n;
    var sxx = 0.0, sxy = 0.0, syy = 0.0;
    for (final r in rows) {
      sxx += (r.chainage - mx) * (r.chainage - mx);
      sxy += (r.chainage - mx) * (r.elev - my);
      syy += (r.elev - my) * (r.elev - my);
    }
    if (sxx > 0) {
      final b1 = sxy / sxx, a1 = my - b1 * mx;
      var ss = 0.0;
      for (final r in rows) {
        final e = r.elev - (a1 + b1 * r.chainage);
        ss += e * e;
      }
      final seRes = n > 2 ? math.sqrt(ss / (n - 2) / sxx) : 0.0;
      final sMean = math.sqrt(rows.fold<double>(0, (t, r) => t + r.sigma * r.sigma) / n);
      final seMeas = sMean / math.sqrt(sxx);
      fit = SlopeFigure(
        method: Method.fit,
        dist: ch,
        dh: b1 * ch,
        slope: b1 * 100,
        unc: math.max(seRes, seMeas) * 100,
        a: a1,
        b: b1,
        r2: syy > 0 ? 1 - ss / syy : 1,
      );
    }
  }
  return SlopeResult(rows, skipped, e2e: e2e, route: route, fit: fit);
}

// ---------------------------------------------------------------- reliability

enum Rel { good, fair, bad, close }

extension RelText on Rel {
  String get label => switch (this) {
        Rel.good => 'Reliable',
        Rel.fair => 'Fair',
        Rel.bad => 'Unreliable',
        Rel.close => 'Too close',
      };
}

Rel? reliability(SlopeFigure? f) {
  if (f == null || f.slope == null || f.unc == null) return null;
  if (f.dist < 10) return Rel.close;
  final q = f.unc! / math.max(f.slope!.abs(), 0.05);
  if (q <= 0.25) return Rel.good;
  if (q <= 0.6) return Rel.fair;
  return Rel.bad;
}

// ---------------------------------------------------------------- slope classes

class SlopeClass {
  const SlopeClass(this.code, this.lo, this.hi, this.name, this.treatment);
  final String code;
  final double lo;
  final double hi;
  final String name;
  final String treatment;
  String get range => hi.isFinite ? '${_n(lo)}–${_n(hi)} %' : '> ${_n(lo)} %';
  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

const List<SlopeClass> slopeClasses = [
  SlopeClass('A', 0, 1, 'Nearly level', 'Field bunding, farm ponds; drainage where water stands.'),
  SlopeClass('B', 1, 3, 'Very gently sloping', 'Field or graded bunds, farm ponds.'),
  SlopeClass('C', 3, 8, 'Gently sloping', 'Contour or graded bunds, compartment bunding.'),
  SlopeClass('D', 8, 15, 'Moderately sloping', 'Contour bunds, terracing, staggered trenches.'),
  SlopeClass('E', 15, 30, 'Moderately steep', 'CCT, staggered trenches, horticulture or agroforestry.'),
  SlopeClass('F', 30, 50, 'Steep', 'CCT, gully plugs, afforestation.'),
  SlopeClass('G', 50, double.infinity, 'Very steep', 'Afforestation and protection; keep out of cultivation.'),
];

SlopeClass classOf(double slopePct) {
  final a = slopePct.abs();
  for (final c in slopeClasses) {
    if (a >= c.lo && a < c.hi) return c;
  }
  return slopeClasses.last;
}

/// Position 0..1 on a dial where each class gets an equal share.
double classDialPosition(double slopePct) {
  final a = slopePct.abs();
  final n = slopeClasses.length;
  for (var i = 0; i < n; i++) {
    final c = slopeClasses[i];
    if (a < c.hi || i == n - 1) {
      final hi = c.hi.isFinite ? c.hi : 80.0;
      final f = ((a - c.lo) / (hi - c.lo)).clamp(0.0, 1.0);
      return (i + f) / n;
    }
  }
  return 1;
}

double slopeDegrees(double pct) => math.atan(pct.abs() / 100) * 180 / math.pi;

String oneIn(double pct) {
  if (pct.abs() < 1e-6) return 'level';
  final v = 100 / pct.abs();
  return '1 in ${v.toStringAsFixed(pct.abs() >= 10 ? 1 : 0)}';
}

// ---------------------------------------------------------------- averaging

/// Averages a burst of GPS readings into one point. Readings much worse than the
/// median horizontal accuracy are dropped; the rest are weighted by 1/accuracy².
SurveyPoint? averageFixes(List<Fix> samples, String label) {
  if (samples.isEmpty) return null;
  final hs = samples.map((s) => s.hAcc).toList()..sort();
  final med = hs[hs.length ~/ 2];
  final cut = math.max(med * 1.5, hs.first + 2);
  final use = samples.where((s) => s.hAcc <= cut).toList();
  var wl = 0.0, la = 0.0, lo = 0.0;
  for (final s in use) {
    final w = 1 / math.pow(math.max(s.hAcc, 1.0), 2);
    wl += w;
    la += s.lat * w;
    lo += s.lon * w;
  }
  final alts = use.where((s) => s.alt != null && s.alt!.isFinite).toList();
  double? alt, sd, altAcc;
  if (alts.isNotEmpty) {
    var wa = 0.0, sa = 0.0;
    for (final s in alts) {
      final w = 1 / math.pow(math.max(s.altAcc ?? 10.0, 1.0), 2);
      wa += w;
      sa += s.alt! * w;
    }
    alt = sa / wa;
    final m = alts.fold<double>(0, (t, s) => t + s.alt!) / alts.length;
    sd = alts.length > 1
        ? math.sqrt(alts.fold<double>(0, (t, s) => t + (s.alt! - m) * (s.alt! - m)) / (alts.length - 1))
        : 0;
    final aa = alts.map((s) => s.altAcc).whereType<double>().toList()..sort();
    altAcc = aa.isNotEmpty ? aa[aa.length ~/ 2] : math.max(5.0, sd);
  }
  final hh = use.map((s) => s.hAcc).toList()..sort();
  return SurveyPoint(
    label: label,
    lat: la / wl,
    lon: lo / wl,
    alt: alt,
    altAcc: altAcc,
    hAcc: hh[hh.length ~/ 2],
    n: use.length,
    sd: sd,
  );
}

// ---------------------------------------------------------------- formatting

String fx(double? v, int d) => (v == null || !v.isFinite) ? '—' : v.toStringAsFixed(d);

String signed(double? v, int d) {
  if (v == null || !v.isFinite) return '—';
  return (v > 0 ? '+' : '') + v.toStringAsFixed(d);
}

String metres(double? v) {
  if (v == null || !v.isFinite) return '—';
  if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(2)} km';
  return '${v.toStringAsFixed(1)} m';
}
