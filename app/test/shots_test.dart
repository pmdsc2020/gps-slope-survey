// Renders every screen at phone size and writes PNGs to shots/.
// Any layout overflow or exception while building a screen fails the test.
//
// Run:  SHOTS=1 flutter test test/shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_slope_survey/core/gps.dart';
import 'package:gps_slope_survey/core/models.dart';
import 'package:gps_slope_survey/core/store.dart';
import 'package:gps_slope_survey/main.dart';
import 'package:gps_slope_survey/screens/shell.dart';
import 'package:gps_slope_survey/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(360, 780);
const Size _tall = Size(360, 1700);
const Size _xtall = Size(360, 2400);

final GlobalKey _shotKey = GlobalKey();
final String _out = Platform.environment['SHOTS_DIR'] ?? 'shots';
final bool _enabled = Platform.environment['SHOTS'] == '1';

Future<void> _loadFonts() async {
  final barlow = FontLoader('BarlowSC');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/BarlowSemiCondensed-$w.ttf').readAsBytesSync();
    barlow.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await barlow.load();
  final icons = Platform.environment['MATERIAL_ICONS'];
  if (icons != null && icons.isNotEmpty && File(icons).existsSync()) {
    final l = FontLoader('MaterialIcons');
    l.addFont(Future<ByteData>.value(ByteData.sublistView(File(icons).readAsBytesSync())));
    await l.load();
  }
  final sans = Platform.environment['FALLBACK_FONT'];
  if (sans != null && sans.isNotEmpty && File(sans).existsSync()) {
    final l = FontLoader('Roboto');
    l.addFont(Future<ByteData>.value(ByteData.sublistView(File(sans).readAsBytesSync())));
    await l.load();
  }
}

Fix _fix({double acc = 3.2}) => Fix(
      lat: 21.825412,
      lon: 74.219875,
      alt: 398.7,
      altAcc: 4.1,
      hAcc: acc,
      time: DateTime.now(),
    );

/// A real-looking survey: six points down a field, last one with an auto-level RL.
Survey _fieldSurvey() {
  final s = Survey(name: 'Bhagdari nala catchment', site: 'Bhagdari', by: 'J. Sonawane');
  const elev = [421.4, 417.9, 413.2, 410.6, 405.1, 401.8];
  for (var i = 0; i < elev.length; i++) {
    s.points.add(SurveyPoint(
      label: 'P${i + 1}',
      lat: 21.83100 - 0.00045 * i,
      lon: 74.22000 + 0.00052 * i + (i.isOdd ? 0.00006 : 0),
      alt: elev[i],
      altAcc: 3.4 + (i % 3) * 0.5,
      hAcc: 2.8 + i % 2,
      n: 29,
      sd: 0.8,
      note: i == 0 ? 'Top of field, near the bund' : '',
    ));
  }
  s.points.last.rl = 401.62;
  s.points.last.note = 'RL from auto level';
  return s;
}

Future<(AppState, GpsService)> _setup(WidgetTester tester, {List<Survey>? surveys}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final s = AppState();
  await tester.runAsync(() => s.init());
  if (surveys != null) s.debugLoad(surveys);
  return (s, GpsService());
}

Future<void> _pump(
  WidgetTester tester,
  AppState s,
  GpsService g, {
  ThemeMode mode = ThemeMode.light,
  Size size = _phone,
  int tab = 0,
  bool splash = false,
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 28, bottom: 16);
  tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 16);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: s),
          ChangeNotifierProvider<GpsService>.value(value: g),
        ],
        child: SlopeApp(splash: splash, themeOverride: mode, startTab: tab),
      ),
    ),
  );
  if (!splash) await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _tab(WidgetTester tester, int i) async {
  tester.state<ShellState>(find.byType(Shell)).go(i);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Motion.ambient = false;
    if (_enabled) await _loadFonts();
  });

  testWidgets('splash', (tester) async {
    final (s, g) = await _setup(tester);
    await _pump(tester, s, g, splash: true);
    await tester.pump(const Duration(milliseconds: 1100));
    await _shot(tester, '00_splash_mid');
    await tester.pump(const Duration(milliseconds: 900));
    await _shot(tester, '00_splash_end');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(Shell), findsOneWidget);
  }, skip: !_enabled);

  testWidgets('survey with example points and a good fix', (tester) async {
    final (s, g) = await _setup(tester);
    g.debugFix(_fix());
    await _pump(tester, s, g);
    await _shot(tester, '01_survey_example');
    tester.view.physicalSize = _xtall;
    await tester.pumpAndSettle();
    await _shot(tester, '01_survey_example_tall');
  }, skip: !_enabled);

  testWidgets('field survey, recording a point', (tester) async {
    final (s, g) = await _setup(tester, surveys: [_fieldSurvey()]);
    g.debugFix(_fix(acc: 7.5));
    await _pump(tester, s, g);
    g.startRecording(30, (_) {}, startedAt: DateTime.now().subtract(const Duration(seconds: 12)));
    for (var i = 0; i < 12; i++) {
      g.debugFix(_fix(acc: 6.5));
      await tester.pump(const Duration(milliseconds: 250));
    }
    await _shot(tester, '02_recording');
    g.cancelRecording();
    await tester.pumpAndSettle();
  }, skip: !_enabled);

  testWidgets('field survey, dark, tall', (tester) async {
    final (s, g) = await _setup(tester, surveys: [_fieldSurvey()]);
    g.debugFix(_fix());
    await _pump(tester, s, g, mode: ThemeMode.dark, size: _xtall);
    await _shot(tester, '03_survey_dark_tall');
  }, skip: !_enabled);

  testWidgets('new survey, GPS blocked', (tester) async {
    final (s, g) = await _setup(tester, surveys: [Survey(name: 'Survey 22-10-2026')]);
    g.debugIssue(GpsIssue.deniedForever);
    await _pump(tester, s, g, size: _tall);
    await _shot(tester, '04_empty_gps_blocked');
  }, skip: !_enabled);

  testWidgets('point sheet', (tester) async {
    final (s, g) = await _setup(tester, surveys: [_fieldSurvey()]);
    await _pump(tester, s, g, size: _tall);
    final f = find.text('417.90 m');
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
    await _shot(tester, '05_point_sheet');
  }, skip: !_enabled);

  testWidgets('result light', (tester) async {
    final (s, g) = await _setup(tester, surveys: [_fieldSurvey()]);
    await _pump(tester, s, g, tab: 1);
    await _shot(tester, '06_result');
    tester.view.physicalSize = _xtall;
    await tester.pumpAndSettle();
    await _shot(tester, '06_result_tall');
  }, skip: !_enabled);

  testWidgets('result dark, best fit', (tester) async {
    final (s, g) = await _setup(tester, surveys: [_fieldSurvey()]);
    await _pump(tester, s, g, tab: 1, mode: ThemeMode.dark, size: _xtall);
    await tester.tap(find.text('Best fit').first);
    await tester.pumpAndSettle();
    await _shot(tester, '07_result_dark_fit');
  }, skip: !_enabled);

  testWidgets('result unreliable', (tester) async {
    final s0 = Survey(name: 'Short line test');
    for (var i = 0; i < 3; i++) {
      s0.points.add(SurveyPoint(
          label: 'P${i + 1}', lat: 21.8 - 0.00012 * i, lon: 74.2, alt: 400 - 0.4 * i, altAcc: 6, hAcc: 4, n: 20));
    }
    final (s, g) = await _setup(tester, surveys: [s0]);
    await _pump(tester, s, g, tab: 1, size: _tall);
    await _shot(tester, '08_result_unreliable');
  }, skip: !_enabled);

  testWidgets('surveys list', (tester) async {
    final a = _fieldSurvey();
    final b = Survey.example();
    final (s, g) = await _setup(tester, surveys: [a, b]);
    await _pump(tester, s, g, tab: 2, size: _xtall);
    await _shot(tester, '09_surveys');
    await _tab(tester, 0);
    await _shot(tester, '09b_back_to_survey');
  }, skip: !_enabled);

  testWidgets('large text', (tester) async {
    final (s, g) = await _setup(tester, surveys: [_fieldSurvey()]);
    g.debugFix(_fix());
    await _pump(tester, s, g, size: _xtall, textScale: 1.3);
    await _shot(tester, '10_large_text');
    await _tab(tester, 1);
    await _shot(tester, '10b_large_text_result');
  }, skip: !_enabled);
}
