import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/gps.dart';
import '../core/models.dart';
import '../core/slope.dart';
import '../core/store.dart';
import '../ui/charts.dart';
import '../ui/contours.dart';
import '../ui/icons.dart';
import '../ui/logo.dart';
import '../ui/record_button.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'point_sheet.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key, required this.onShowResult, required this.onOpenSurveys});
  final VoidCallback onShowResult;
  final VoidCallback onOpenSurveys;

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _savedTick = 0;

  void _record() {
    final gps = context.read<GpsService>();
    final state = context.read<AppState>();
    if (!gps.running) {
      gps.start();
      toast(context, 'Starting GPS. Record once the fix appears.');
      return;
    }
    if (gps.last == null) {
      toast(context, 'Waiting for the first GPS fix');
      return;
    }
    if (gps.recording) return;
    if (state.current.example) {
      toast(context, 'Start a new survey first, so the example points are not mixed in',
          action: SnackBarAction(label: 'New survey', onPressed: () => state.newSurvey()));
      return;
    }
    final label = state.nextLabel();
    gps.startRecording(state.averagingSeconds, (samples) {
      final pt = averageFixes(samples, label);
      if (!mounted) return;
      if (pt == null) {
        toast(context, 'No GPS readings came in. Move to open sky and try again.');
        return;
      }
      state.addPoint(pt);
      setState(() => _savedTick++);
      toast(
          context,
          pt.alt == null
              ? '${pt.label} saved without altitude. Tap it to type an RL.'
              : '${pt.label} saved from ${pt.n} readings');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final gps = context.watch<GpsService>();
    final p = context.pal;
    final s = state.current;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _LiveBand(survey: s),
        if (s.example) _ExampleBanner(onNew: () => state.newSurvey()),
        if (gps.issue != GpsIssue.none || gps.slow) const _GpsHelp(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Average each point for', style: T.head(p.ink))),
                  ],
                ),
                const SizedBox(height: 10),
                Slider3<int>(
                  values: const [10, 30, 60],
                  labels: const ['10 s', '30 s', '60 s'],
                  value: state.averagingSeconds,
                  onChanged: gps.recording ? (_) {} : state.setAveraging,
                ),
                const SizedBox(height: 18),
                RecordButton(
                  ready: gps.state == GpsState.fix,
                  recording: gps.recording,
                  progress: gps.rec?.progress ?? 0,
                  secondsLeft: gps.rec?.secondsLeft ?? 0,
                  readings: gps.rec?.samples.length ?? 0,
                  label: state.nextLabel(),
                  savedTick: _savedTick,
                  onTap: _record,
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: gps.recording
                      ? TextButton.icon(
                          key: const ValueKey('cancel'),
                          onPressed: () {
                            gps.cancelRecording();
                            toast(context, 'Recording cancelled');
                          },
                          icon: Icon(Icons.close_rounded, color: p.bad),
                          label: Text('Cancel recording', style: T.head(p.bad)),
                        )
                      : Text(
                          key: const ValueKey('hint'),
                          'Stand still at the point. Hold the phone flat, at the same height for every point.',
                          textAlign: TextAlign.center,
                          style: T.small(p.muted),
                        ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Points along the line', style: T.title(p.ink)),
                    Text(
                        s.points.isEmpty
                            ? 'From the top point downhill'
                            : '${s.points.length} point${s.points.length == 1 ? '' : 's'} · tap to edit, swipe to delete',
                        style: T.small(p.muted)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Enter a point by hand',
                onPressed: () {
                  if (s.example) {
                    toast(context, 'Start a new survey first');
                    return;
                  }
                  showManualSheet(context);
                },
                icon: const Icon(Icons.add_location_alt_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Transect(survey: s),
        if (computeSlope(s.points).ok)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: WideButton(icon: Icons.insights_rounded, label: 'See the slope result', onTap: widget.onShowResult, primary: true),
          ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ------------------------------------------------------------------ band

class _LiveBand extends StatelessWidget {
  const _LiveBand({required this.survey});
  final Survey survey;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final gps = context.watch<GpsService>();
    final state = context.watch<AppState>();
    final f = gps.last;
    final q = gps.quality;
    final status = switch (gps.state) {
      GpsState.off => 'GPS is off',
      GpsState.starting => 'Starting GPS…',
      GpsState.searching => 'Searching for satellites…',
      GpsState.error => 'GPS could not start',
      GpsState.fix => switch (q) {
          FixQuality.good => 'Good fix',
          FixQuality.fair => 'Fair fix',
          _ => 'Weak fix · open sky',
        },
    };
    final statusColor = switch (gps.state) {
      GpsState.fix => switch (q) {
          FixQuality.good => p.bandGood,
          FixQuality.fair => p.bandWarn,
          _ => p.bandBad,
        },
      GpsState.error => p.bandBad,
      GpsState.off => p.bandMuted,
      _ => p.amber,
    };
    return Band(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 8, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LogoMark(size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GPS Slope Survey', style: T.title(p.bandInk)),
                      Text(
                        survey.site.isEmpty ? survey.name : '${survey.name} · ${survey.site}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.small(p.bandMuted),
                      ),
                    ],
                  ),
                ),
                ThemeToggle(mode: state.themeMode, onChanged: state.setTheme, color: p.bandInk),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GpsRadar(state: gps.state, quality: q, size: 50),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(status, key: ValueKey(status), style: T.head(statusColor)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                f == null
                                    ? (gps.running ? 'Keep the phone under open sky' : 'Tap Start to read your position')
                                    : '${f.lat.toStringAsFixed(6)}, ${f.lon.toStringAsFixed(6)}',
                                style: T.num(p.bandMuted, size: 13.5, w: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        _GpsButton(on: gps.running, onTap: () => gps.running ? gps.stop() : gps.start()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _BandFigure(
                            label: 'Altitude',
                            value: f == null ? '—' : (f.alt == null ? 'n/a' : f.alt!.toStringAsFixed(1)),
                            unit: f?.alt == null ? '' : 'm',
                            big: true,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _BandFigure(
                            label: '± Vertical',
                            value: f?.altAcc == null ? '—' : f!.altAcc!.toStringAsFixed(1),
                            unit: f?.altAcc == null ? '' : 'm',
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _BandFigure(
                            label: '± Horizontal',
                            value: f == null ? '—' : f.hAcc.toStringAsFixed(1),
                            unit: f == null ? '' : 'm',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandFigure extends StatelessWidget {
  const _BandFigure({required this.label, required this.value, required this.unit, this.big = false});
  final String label, value, unit;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: T.label(p.bandMuted).copyWith(fontSize: 10.5), maxLines: 1),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: T.num(p.bandInk, size: big ? 34 : 20, w: FontWeight.w700)),
              if (unit.isNotEmpty)
                TextSpan(text: ' $unit', style: T.num(p.bandMuted, size: big ? 16 : 13, w: FontWeight.w500)),
            ]),
          ),
        ),
      ],
    );
  }
}

class _GpsButton extends StatelessWidget {
  const _GpsButton({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: on ? Colors.white.withOpacity(0.08) : p.amber,
      shape: StadiumBorder(side: BorderSide(color: on ? Colors.white.withOpacity(0.3) : p.amber)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(on ? Icons.stop_rounded : Icons.satellite_alt_rounded, size: 18, color: on ? p.bandInk : p.amberInk),
              const SizedBox(width: 6),
              Text(on ? 'Stop' : 'Start', style: T.head(on ? p.bandInk : p.amberInk).copyWith(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExampleBanner extends StatelessWidget {
  const _ExampleBanner({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: p.amber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.amber.withOpacity(0.7)),
        ),
        child: Row(
          children: [
            Icon(Icons.science_outlined, color: p.warn),
            const SizedBox(width: 10),
            Expanded(child: Text('These are example points, not your survey.', style: T.body(p.ink))),
            TextButton(onPressed: onNew, child: Text('Start new', style: T.head(p.field))),
          ],
        ),
      ),
    );
  }
}

class _GpsHelp extends StatelessWidget {
  const _GpsHelp();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final gps = context.watch<GpsService>();
    final (String title, String text, String? action, VoidCallback? onAction) = switch (gps.issue) {
      GpsIssue.serviceOff => (
          'Location is turned off',
          'Turn on Location in the phone, with Google Location Accuracy on, then tap Start again.',
          'Open location settings',
          gps.openLocationSettings,
        ),
      GpsIssue.denied => (
          'Location permission was refused',
          'The app needs location to read GPS. Tap Start and choose "While using the app".',
          'Try again',
          gps.start,
        ),
      GpsIssue.deniedForever => (
          'Location permission is blocked',
          'Open the app settings, choose Permissions, then Location, then Allow, and turn on "Use precise location".',
          'Open app settings',
          gps.openAppSettings,
        ),
      GpsIssue.unavailable => (
          'GPS is not available',
          gps.detail ?? 'This phone did not return a position.',
          'Try again',
          gps.start,
        ),
      GpsIssue.none => (
          'No fix yet after 25 seconds',
          'Stand in open sky away from buildings and trees. Check Location is on with Google Location Accuracy. Still trying…',
          null,
          null,
        ),
    };
    final bad = gps.issue != GpsIssue.none;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (bad ? p.bad : p.warn).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bad ? p.bad : p.warn),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(bad ? Icons.location_disabled_rounded : Icons.hourglass_top_rounded, color: bad ? p.bad : p.warn),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: T.head(p.ink))),
            ]),
            const SizedBox(height: 6),
            Text(text, style: T.body(p.ink)),
            if (action != null) ...[
              const SizedBox(height: 10),
              WideButton(icon: Icons.settings_rounded, label: action, onTap: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ transect

class _Transect extends StatelessWidget {
  const _Transect({required this.survey});
  final Survey survey;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pts = survey.points;
    if (pts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.line, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(Icons.route_rounded, size: 36, color: p.muted),
              const SizedBox(height: 8),
              Text('No points yet', style: T.head(p.ink)),
              const SizedBox(height: 4),
              Text('Start GPS, stand at the top point and record P1. Then walk down the slope and record the next points.',
                  textAlign: TextAlign.center, style: T.small(p.muted)),
            ],
          ),
        ),
      );
    }
    // segment figures keyed by the point they end at
    final res = computeSlope(pts);
    final seg = {for (final r in res.rows) r.point.id: r};
    final children = <Widget>[];
    for (var i = 0; i < pts.length; i++) {
      final pt = pts[i];
      final row = seg[pt.id];
      if (i > 0) {
        children.add(_Connector(row: row));
      }
      children.add(Stagger(
        index: i,
        child: _Node(point: pt, first: i == 0, last: i == pts.length - 1, index: i),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: children),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.row});
  final ProfileRow? row;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = row?.slope;
    final fall = (row?.dh ?? 0) < 0;
    final col = s == null ? p.muted : classColors[slopeClasses.indexOf(classOf(s))];
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Center(child: Container(width: 3, color: p.field.withOpacity(0.45))),
          ),
          if (row != null && s != null)
            Flexible(
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Icon(fall ? Icons.south_east_rounded : Icons.north_east_rounded, size: 16, color: p.ink),
                  const SizedBox(width: 4),
                  Text('${signed(s, 2)} %', style: T.num(p.ink, size: 14, w: FontWeight.w700)),
                  Flexible(
                    child: Text('  ·  ${fx(row!.dist, 1)} m  ·  Δh ${signed(row!.dh, 2)} m',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.num(p.muted, size: 13, w: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            )
          else
            Text('no elevation', style: T.small(p.bad)),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.point, required this.first, required this.last, required this.index});
  final SurveyPoint point;
  final bool first, last;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final state = context.read<AppState>();
    final e = point.elevation;
    final missing = e == null;
    return Dismissible(
      key: ValueKey('node-${point.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(color: p.bad, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        final i = state.removePoint(point);
        HapticFeedback.mediumImpact();
        toast(context, '${point.label} deleted',
            action: SnackBarAction(label: 'Undo', onPressed: () => state.insertPoint(i, point)));
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: first ? p.amber : p.surface,
                border: Border.all(color: missing ? p.bad : p.field, width: 2.5),
              ),
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(point.label, style: T.head(first ? p.amberInk : p.field).copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => showPointSheet(context, point),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(e == null ? 'No elevation' : '${e.toStringAsFixed(2)} m',
                                    style: T.num(missing ? p.bad : p.ink, size: 19, w: FontWeight.w700)),
                                Chip2(
                                  text: point.source,
                                  color: point.source == 'GPS' ? p.muted : p.field,
                                ),
                                if (!point.hasRL && point.altAcc != null)
                                  Text('±${point.altAcc!.toStringAsFixed(1)} m',
                                      style: T.num(p.muted, size: 13, w: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${point.lat.toStringAsFixed(6)}, ${point.lon.toStringAsFixed(6)}'
                              '${point.n > 0 ? '  ·  ${point.n} readings' : ''}',
                              style: T.num(p.muted, size: 12.5, w: FontWeight.w400),
                            ),
                            if (point.note.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(point.note, style: T.small(p.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
