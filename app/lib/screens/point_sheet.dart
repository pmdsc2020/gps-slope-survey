import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/gps.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

final _num = FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'));

Future<void> showPointSheet(BuildContext context, SurveyPoint point) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PointSheet(point: point),
  );
}

Future<void> showManualSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ManualSheet(),
  );
}

class _PointSheet extends StatefulWidget {
  const _PointSheet({required this.point});
  final SurveyPoint point;

  @override
  State<_PointSheet> createState() => _PointSheetState();
}

class _PointSheetState extends State<_PointSheet> {
  late final _label = TextEditingController(text: widget.point.label);
  late final _rl = TextEditingController(text: widget.point.hasRL ? widget.point.rl!.toString() : '');
  late final _note = TextEditingController(text: widget.point.note);
  bool _armed = false;

  @override
  void dispose() {
    _label.dispose();
    _rl.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final state = context.read<AppState>();
    final pt = widget.point;
    final rlText = _rl.text.trim();
    final rl = rlText.isEmpty ? null : double.tryParse(rlText);
    if (rlText.isNotEmpty && rl == null) {
      toast(context, 'RL must be a number in metres');
      return;
    }
    if (rl == null && pt.manual) {
      toast(context, 'A point entered by hand needs an elevation');
      return;
    }
    pt.label = _label.text.trim().isEmpty ? pt.label : _label.text.trim();
    pt.rl = rl;
    pt.note = _note.text.trim();
    state.touch();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pt = widget.point;
    final state = context.read<AppState>();
    final pts = state.current.points;
    final i = pts.indexWhere((e) => e.id == pt.id);
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Point ${pt.label}', style: T.title(p.ink).copyWith(fontSize: 22)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.raised, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Stat(label: 'GPS altitude', value: pt.alt == null ? '—' : '${pt.alt!.toStringAsFixed(2)} m')),
                      Expanded(child: Stat(label: '± Vertical', value: pt.altAcc == null ? '—' : '${pt.altAcc!.toStringAsFixed(1)} m')),
                      Expanded(
                          child: Stat(
                              label: 'Readings',
                              value: pt.n == 0 ? '—' : '${pt.n}${pt.sd != null ? '  σ ${pt.sd!.toStringAsFixed(1)}' : ''}')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${pt.lat.toStringAsFixed(7)}, ${pt.lon.toStringAsFixed(7)}'
                    '${pt.hAcc != null ? '  ·  ±${pt.hAcc!.toStringAsFixed(1)} m horizontal' : ''}',
                    style: T.num(p.muted, size: 13, w: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _label,
                    decoration: const InputDecoration(labelText: 'Label'),
                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _rl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [_num],
                    decoration: InputDecoration(
                      labelText: 'RL / elevation (m)',
                      hintText: pt.manual ? '' : 'blank = use GPS',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note', hintText: 'e.g. nala bank, field corner'),
            ),
            const SizedBox(height: 6),
            Text('Type an RL from an auto level to use it instead of the GPS height.', style: T.small(p.muted)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: WideButton(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Move up',
                    onTap: i <= 0
                        ? null
                        : () {
                            state.movePoint(pt, -1);
                            Navigator.pop(context);
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WideButton(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Move down',
                    onTap: i < 0 || i >= pts.length - 1
                        ? null
                        : () {
                            state.movePoint(pt, 1);
                            Navigator.pop(context);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: WideButton(
                    icon: Icons.delete_outline_rounded,
                    label: _armed ? 'Tap again to delete' : 'Delete',
                    danger: true,
                    onTap: () {
                      if (!_armed) {
                        setState(() => _armed = true);
                        return;
                      }
                      final idx = state.removePoint(pt);
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(SnackBar(
                        content: Text('${pt.label} deleted'),
                        action: SnackBarAction(label: 'Undo', onPressed: () => state.insertPoint(idx, pt)),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: WideButton(icon: Icons.check_rounded, label: 'Save', primary: true, onTap: _save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualSheet extends StatefulWidget {
  const _ManualSheet();

  @override
  State<_ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<_ManualSheet> {
  late final AppState state = context.read<AppState>();
  late final Fix? fix = context.read<GpsService>().last;
  late final _label = TextEditingController(text: state.nextLabel());
  final _el = TextEditingController();
  late final _lat = TextEditingController(text: fix?.lat.toStringAsFixed(6) ?? '');
  late final _lon = TextEditingController(text: fix?.lon.toStringAsFixed(6) ?? '');
  final _note = TextEditingController();

  @override
  void dispose() {
    for (final c in [_label, _el, _lat, _lon, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    final lat = double.tryParse(_lat.text.trim()), lon = double.tryParse(_lon.text.trim());
    final el = double.tryParse(_el.text.trim());
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      toast(context, 'Enter latitude and longitude in decimal degrees');
      return;
    }
    if (el == null) {
      toast(context, 'Enter the elevation in metres');
      return;
    }
    state.addPoint(SurveyPoint(
      label: _label.text.trim().isEmpty ? state.nextLabel() : _label.text.trim(),
      lat: lat,
      lon: lon,
      rl: el,
      note: _note.text.trim(),
      manual: true,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    InputDecoration d(String l) => InputDecoration(labelText: l);
    const numKb = TextInputType.numberWithOptions(decimal: true, signed: true);
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter a point', style: T.title(p.ink).copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              'For points read from Google Earth, a toposheet or an auto level.'
              '${fix != null ? ' Position is filled from the live GPS.' : ''}',
              style: T.small(p.muted),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(flex: 2, child: TextField(controller: _label, decoration: d('Label'))),
              const SizedBox(width: 10),
              Expanded(
                  flex: 3,
                  child: TextField(controller: _el, keyboardType: numKb, inputFormatters: [_num], decoration: d('Elevation (m)'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(controller: _lat, keyboardType: numKb, inputFormatters: [_num], decoration: d('Latitude'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(controller: _lon, keyboardType: numKb, inputFormatters: [_num], decoration: d('Longitude'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: d('Note')),
            const SizedBox(height: 16),
            WideButton(icon: Icons.add_location_alt_rounded, label: 'Add point', primary: true, onTap: _add),
          ],
        ),
      ),
    );
  }
}
