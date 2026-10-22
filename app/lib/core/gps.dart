import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';

enum GpsState { off, starting, searching, fix, error }

enum GpsIssue { none, serviceOff, denied, deniedForever, unavailable }

enum FixQuality { good, fair, weak }

class Recording {
  Recording(this.seconds, {DateTime? started}) : started = started ?? DateTime.now();
  final int seconds;
  final DateTime started;
  final List<Fix> samples = [];
  double get progress {
    final ms = DateTime.now().difference(started).inMilliseconds;
    return (ms / (seconds * 1000)).clamp(0.0, 1.0);
  }

  int get secondsLeft {
    final left = seconds - DateTime.now().difference(started).inMilliseconds / 1000;
    return left <= 0 ? 0 : left.ceil();
  }
}

/// Live GPS from the phone, plus the averaging of a burst of readings into one point.
class GpsService extends ChangeNotifier {
  static const _screen = MethodChannel('slope_survey/screen');

  GpsState state = GpsState.off;
  GpsIssue issue = GpsIssue.none;
  String? detail;
  Fix? last;
  bool slow = false;
  Recording? rec;

  StreamSubscription<Position>? _sub;
  Timer? _slowTimer;
  Timer? _tick;
  void Function(List<Fix> samples)? _onDone;

  bool get running => state == GpsState.starting || state == GpsState.searching || state == GpsState.fix;
  bool get recording => rec != null;

  FixQuality? get quality {
    final f = last;
    if (f == null || state != GpsState.fix) return null;
    if (f.hAcc <= 5 && (f.altAcc == null || f.altAcc! <= 8)) return FixQuality.good;
    if (f.hAcc <= 15) return FixQuality.fair;
    return FixQuality.weak;
  }

  Future<void> start() async {
    if (running) return;
    issue = GpsIssue.none;
    detail = null;
    slow = false;
    state = GpsState.starting;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _fail(GpsIssue.serviceOff);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return _fail(GpsIssue.deniedForever);
      if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) {
        return _fail(GpsIssue.denied);
      }
      state = GpsState.searching;
      notifyListeners();
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 1),
            )
          : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        _onPosition,
        onError: (Object e) {
          if (e is LocationServiceDisabledException) {
            _fail(GpsIssue.serviceOff);
          } else if (e is PermissionDeniedException) {
            _fail(GpsIssue.denied);
          } else {
            detail = e.toString();
            notifyListeners();
          }
        },
      );
      _keepScreenOn(true);
      _slowTimer?.cancel();
      _slowTimer = Timer(const Duration(seconds: 25), () {
        if (state == GpsState.searching) {
          slow = true;
          notifyListeners();
        }
      });
    } catch (e) {
      detail = e.toString();
      _fail(GpsIssue.unavailable);
    }
  }

  void _onPosition(Position p) {
    final alt = p.altitude;
    final altAcc = p.altitudeAccuracy;
    final f = Fix(
      lat: p.latitude,
      lon: p.longitude,
      // Some phones report 0.0 when they have no altitude at all.
      alt: (alt == 0 && (altAcc <= 0)) ? null : alt,
      altAcc: altAcc > 0 ? altAcc : null,
      hAcc: p.accuracy,
      time: DateTime.now(),
    );
    _accept(f);
  }

  void _accept(Fix f) {
    last = f;
    slow = false;
    issue = GpsIssue.none;
    state = GpsState.fix;
    rec?.samples.add(f);
    notifyListeners();
  }

  void _fail(GpsIssue i) {
    _sub?.cancel();
    _sub = null;
    _slowTimer?.cancel();
    cancelRecording(notify: false);
    issue = i;
    state = GpsState.error;
    _keepScreenOn(false);
    notifyListeners();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _slowTimer?.cancel();
    cancelRecording(notify: false);
    state = GpsState.off;
    issue = GpsIssue.none;
    last = null;
    slow = false;
    _keepScreenOn(false);
    notifyListeners();
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  // ------------------------------------------------ recording

  void startRecording(int seconds, void Function(List<Fix> samples) onDone, {DateTime? startedAt}) {
    if (rec != null || last == null) return;
    final r = Recording(seconds, started: startedAt);
    final f = last!;
    if (DateTime.now().difference(f.time).inMilliseconds < 2500) r.samples.add(f);
    rec = r;
    _onDone = onDone;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final cur = rec;
      if (cur == null) return;
      if (cur.progress >= 1) {
        _finish();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _finish() {
    final r = rec;
    _tick?.cancel();
    rec = null;
    final cb = _onDone;
    _onDone = null;
    if (r != null && cb != null) cb(List.of(r.samples));
    notifyListeners();
  }

  void cancelRecording({bool notify = true}) {
    _tick?.cancel();
    rec = null;
    _onDone = null;
    if (notify) notifyListeners();
  }

  void _keepScreenOn(bool on) {
    _screen.invokeMethod<void>('keepOn', on).catchError((Object _) {});
  }

  // ------------------------------------------------ tests

  @visibleForTesting
  void debugFix(Fix f) => _accept(f);

  @visibleForTesting
  void debugIssue(GpsIssue i) {
    issue = i;
    state = GpsState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _slowTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }
}
