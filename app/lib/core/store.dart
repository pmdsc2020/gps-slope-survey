import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'slope.dart';

/// Holds every survey on this phone and the user's settings.
class AppState extends ChangeNotifier {
  static const _key = 'gpsSlopeSurvey.v1';
  static const _uiKey = 'gpsSlopeSurvey.ui';

  SharedPreferences? _prefs;
  final Map<String, Survey> surveys = {};
  String _cur = '';
  int averagingSeconds = 30;
  Method method = Method.e2e;
  ThemeMode themeMode = ThemeMode.system;

  Survey get current => surveys[_cur] ?? surveys.values.first;

  List<Survey> get sorted =>
      surveys.values.toList()..sort((a, b) => b.created.compareTo(a.created));

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs!.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final m = Map<String, dynamic>.from(j['surveys'] as Map);
        for (final e in m.values) {
          final s = Survey.fromJson(Map<String, dynamic>.from(e as Map));
          surveys[s.id] = s;
        }
        _cur = (j['cur'] ?? '') as String;
      }
    } catch (_) {
      surveys.clear();
    }
    if (surveys.isEmpty) {
      final ex = Survey.example();
      surveys[ex.id] = ex;
      _cur = ex.id;
    }
    if (!surveys.containsKey(_cur)) _cur = sorted.first.id;
    try {
      final u = _prefs!.getString(_uiKey);
      if (u != null) {
        final j = jsonDecode(u) as Map<String, dynamic>;
        averagingSeconds = (j['dur'] as num?)?.toInt() ?? 30;
        method = Method.values.firstWhere((m) => m.name == j['method'], orElse: () => Method.e2e);
        themeMode =
            ThemeMode.values.firstWhere((m) => m.name == j['theme'], orElse: () => ThemeMode.system);
      }
    } catch (_) {}
    notifyListeners();
  }

  void _save() {
    final j = {
      'cur': _cur,
      'surveys': {for (final s in surveys.values) s.id: s.toJson()},
    };
    _prefs?.setString(_key, jsonEncode(j));
  }

  void _saveUi() {
    _prefs?.setString(_uiKey,
        jsonEncode({'dur': averagingSeconds, 'method': method.name, 'theme': themeMode.name}));
  }

  void touch() {
    _save();
    notifyListeners();
  }

  // ------------------------------------------------ settings

  void setAveraging(int s) {
    averagingSeconds = s;
    _saveUi();
    notifyListeners();
  }

  void setMethod(Method m) {
    method = m;
    _saveUi();
    notifyListeners();
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    _saveUi();
    notifyListeners();
  }

  // ------------------------------------------------ surveys

  Survey newSurvey() {
    surveys.removeWhere((_, s) => s.example);
    final d = DateTime.now();
    final s = Survey(name: 'Survey ${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}');
    surveys[s.id] = s;
    _cur = s.id;
    touch();
    return s;
  }

  void open(String id) {
    if (!surveys.containsKey(id)) return;
    _cur = id;
    touch();
  }

  void deleteSurvey(String id) {
    surveys.remove(id);
    if (surveys.isEmpty) {
      final s = Survey(name: 'Survey 1');
      surveys[s.id] = s;
    }
    if (!surveys.containsKey(_cur)) _cur = sorted.first.id;
    touch();
  }

  void updateMeta({String? name, String? site, String? by, String? rem}) {
    final s = current;
    if (name != null) s.name = name;
    if (site != null) s.site = site;
    if (by != null) s.by = by;
    if (rem != null) s.rem = rem;
    touch();
  }

  // ------------------------------------------------ points

  String nextLabel() {
    var m = 0;
    final re = RegExp(r'^P(\d+)$', caseSensitive: false);
    for (final p in current.points) {
      final r = re.firstMatch(p.label);
      if (r != null) {
        final v = int.parse(r.group(1)!);
        if (v > m) m = v;
      }
    }
    return 'P${m + 1}';
  }

  void addPoint(SurveyPoint p) {
    current.points.add(p);
    touch();
  }

  void insertPoint(int index, SurveyPoint p) {
    final pts = current.points;
    pts.insert(index.clamp(0, pts.length), p);
    touch();
  }

  int removePoint(SurveyPoint p) {
    final i = current.points.indexWhere((e) => e.id == p.id);
    if (i >= 0) current.points.removeAt(i);
    touch();
    return i;
  }

  void movePoint(SurveyPoint p, int delta) {
    final pts = current.points;
    final i = pts.indexWhere((e) => e.id == p.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= pts.length) return;
    final t = pts[i];
    pts[i] = pts[j];
    pts[j] = t;
    touch();
  }

  /// For tests: replace everything with the given surveys.
  @visibleForTesting
  void debugLoad(List<Survey> list, {String? current}) {
    surveys
      ..clear()
      ..addEntries(list.map((s) => MapEntry(s.id, s)));
    _cur = current ?? list.first.id;
    notifyListeners();
  }
}
