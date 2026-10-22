import 'package:flutter_test/flutter_test.dart';
import 'package:gps_slope_survey/core/export.dart';
import 'package:gps_slope_survey/core/models.dart';
import 'package:gps_slope_survey/core/slope.dart';

void main() {
  test('one arc-minute of latitude is about 1853 m', () {
    expect(haversine(21, 74, 21 + 1 / 60, 74), closeTo(1853.3, 0.5));
  });

  test('example transect matches the web app', () {
    final s = Survey.example();
    final r = computeSlope(s.points);
    expect(r.n, 6);
    expect(r.e2e!.dist, closeTo(286.8, 0.1));
    expect(r.e2e!.slope, closeTo(-6.00, 0.01));
    expect(r.route!.dist, closeTo(287.2, 0.1));
    expect(r.rows[1].slope, closeTo(-5.85, 0.01));
    expect(r.fit, isNotNull);
    expect(r.fit!.r2!, greaterThan(0.95));
    expect(classOf(r.e2e!.slope!).code, 'C');
    expect(reliability(r.e2e), Rel.fair);
  });

  test('typed RL overrides GPS height', () {
    final s = Survey.example();
    s.points.first.rl = 500;
    expect(s.points.first.elevation, 500);
    expect(s.points.first.sigma, 0.02);
    expect(s.points.first.source, 'RL');
  });

  test('points without elevation are skipped', () {
    final s = Survey.example();
    s.points.add(SurveyPoint(label: 'P7', lat: 21.8, lon: 74.2));
    final r = computeSlope(s.points);
    expect(r.n, 6);
    expect(r.skipped, 1);
  });

  test('averaging drops bad readings and weights the rest', () {
    final t = DateTime(2026);
    final fixes = [
      for (var i = 0; i < 10; i++)
        Fix(lat: 21.0 + i * 1e-7, lon: 74.0, alt: 400.0 + (i.isEven ? 1 : -1), altAcc: 4, hAcc: 4, time: t),
      Fix(lat: 21.01, lon: 74.01, alt: 300, altAcc: 30, hAcc: 60, time: t), // outlier
    ];
    final p = averageFixes(fixes, 'P1')!;
    expect(p.n, 10);
    expect(p.lat, closeTo(21.0, 1e-5));
    expect(p.alt, closeTo(400.0, 0.01));
    expect(p.altAcc, 4);
    expect(p.label, 'P1');
  });

  test('class dial position rises with slope', () {
    var last = -1.0;
    for (final v in [0.0, 0.5, 2.0, 5.0, 10.0, 20.0, 40.0, 70.0]) {
      final x = classDialPosition(v);
      expect(x, greaterThan(last));
      last = x;
    }
    expect(classDialPosition(1000), 1.0);
  });

  test('one in n and degrees', () {
    expect(oneIn(6), '1 in 17');
    expect(oneIn(25), '1 in 4.0');
    expect(slopeDegrees(100), closeTo(45, 1e-9));
  });

  test('exports carry every point', () {
    final s = Survey.example();
    final csv = csvText(s);
    expect(csv.split('\n').where((l) => RegExp(r'^P\d+,').hasMatch(l)).length, 6);
    expect(kmlText(s), contains('<LineString>'));
    expect(summaryText(s, Method.e2e), contains('Slope class: C'));
  });
}
