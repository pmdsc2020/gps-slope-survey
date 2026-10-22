import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/gps.dart';
import '../core/models.dart';
import '../core/slope.dart';
import '../core/store.dart';
import '../ui/charts.dart';
import '../ui/contours.dart';
import '../ui/logo.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SurveysScreen extends StatelessWidget {
  const SurveysScreen({super.key, required this.onOpened});
  final VoidCallback onOpened;

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.pal;
    final list = state.sorted;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Band(
          hillAt: const Alignment(0.3, -1.4),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 22),
            child: Row(
              children: [
                const LogoMark(size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Surveys', style: T.big(p.bandInk).copyWith(fontSize: 28)),
                      Text('${list.length} saved on this phone', style: T.small(p.bandMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _CurrentForm(key: ValueKey(state.current.id), survey: state.current),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: WideButton(
            icon: Icons.add_road_rounded,
            label: 'Start new survey',
            primary: true,
            onTap: () {
              context.read<GpsService>().cancelRecording();
              state.newSurvey();
              toast(context, 'New survey started · record P1 at the top point');
              onOpened();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
          child: Eyebrow('Saved surveys'),
        ),
        for (final (i, s) in list.indexed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Stagger(
              index: i,
              child: _SurveyCard(
                survey: s,
                current: s.id == state.current.id,
                date: _date(s.createdAt),
                onOpen: () {
                  context.read<GpsService>().cancelRecording();
                  state.open(s.id);
                  onOpened();
                },
                onDelete: () => _confirmDelete(context, s),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Panel(
            title: 'Getting a usable slope from phone GPS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Tip(icon: Icons.straighten_rounded, text: 'Phone GPS height is far weaker than position: expect ±3 to ±15 m. Keep points far apart, about 100 m or more on gentle land.'),
                _Tip(icon: Icons.timer_outlined, text: 'Record every point with the same averaging time, in open sky, after the fix turns green.'),
                _Tip(icon: Icons.south_east_rounded, text: 'Walk the line of steepest slope, from the top point to the bottom point.'),
                _Tip(icon: Icons.edit_note_rounded, text: 'When the result says Unreliable, type RLs from an auto level into the points. The app then uses those RLs.'),
                _Tip(icon: Icons.layers_outlined, text: 'GPS altitude is height above the WGS84 ellipsoid. That offset cancels out in slope, so do not mix GPS heights with RLs from a benchmark in one survey.'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Panel(
            title: 'Appearance',
            child: Slider3<ThemeMode>(
              values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labels: const ['Phone', 'Light', 'Dark'],
              value: state.themeMode,
              onChanged: state.setTheme,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
          child: Column(
            children: [
              const LogoMark(size: 34),
              const SizedBox(height: 8),
              Text('GPS Slope Survey · version 1.0', style: T.head(p.ink)),
              const SizedBox(height: 2),
              Text('Developed by Jitendra Sonawane, Agriculture Engineer · 7720045808',
                  textAlign: TextAlign.center, style: T.small(p.muted)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Survey s) async {
    final p = context.pal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${s.name}"?'),
        content: Text('Its ${s.points.length} points are removed from this phone. Export a CSV first if you need them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep', style: T.head(p.ink))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: T.head(p.bad))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<AppState>().deleteSurvey(s.id);
      toast(context, 'Survey deleted');
    }
  }
}

class _CurrentForm extends StatefulWidget {
  const _CurrentForm({super.key, required this.survey});
  final Survey survey;

  @override
  State<_CurrentForm> createState() => _CurrentFormState();
}

class _CurrentFormState extends State<_CurrentForm> {
  late final _name = TextEditingController(text: widget.survey.name);
  late final _site = TextEditingController(text: widget.survey.site);
  late final _by = TextEditingController(text: widget.survey.by);
  late final _rem = TextEditingController(text: widget.survey.rem);

  @override
  void dispose() {
    for (final c in [_name, _site, _by, _rem]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Panel(
      title: 'Open survey',
      child: Column(
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Survey name'),
            onChanged: (v) => state.updateMeta(name: v),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _site,
                decoration: const InputDecoration(labelText: 'Village / site'),
                onChanged: (v) => state.updateMeta(site: v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _by,
                decoration: const InputDecoration(labelText: 'Surveyor'),
                onChanged: (v) => state.updateMeta(by: v),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _rem,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Remarks'),
            onChanged: (v) => state.updateMeta(rem: v),
          ),
        ],
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  const _SurveyCard({
    required this.survey,
    required this.current,
    required this.date,
    required this.onOpen,
    required this.onDelete,
  });
  final Survey survey;
  final bool current;
  final String date;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = computeSlope(survey.points);
    final e = r.e2e?.slope;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: current ? null : onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: current ? p.field : p.line, width: current ? 2 : 1),
          ),
          child: Row(
            children: [
              Sparkline(result: r),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(survey.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.head(p.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${survey.site.isEmpty ? '' : '${survey.site} · '}$date · ${survey.points.length} pts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.small(p.muted),
                    ),
                    if (current || survey.example) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        if (current) Chip2(text: 'Open', color: p.field),
                        if (survey.example) Chip2(text: 'Example', color: p.warn),
                      ]),
                    ],
                  ],
                ),
              ),
              if (e != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fx(e.abs(), 1)}%', style: T.num(p.ink, size: 18, w: FontWeight.w700)),
                    Text('class ${classOf(e).code}', style: T.small(p.muted)),
                  ],
                ),
              ],
              IconButton(
                tooltip: 'Delete survey',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 18, color: p.field),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: T.body(p.ink))),
        ],
      ),
    );
  }
}
