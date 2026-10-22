import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/export.dart';
import '../core/slope.dart';
import '../core/store.dart';
import '../ui/charts.dart';
import '../ui/contours.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.pal;
    final s = state.current;
    final r = computeSlope(s.points);
    final method = (state.method == Method.fit && r.fit == null) ? Method.e2e : state.method;
    final f = r.by(method);
    final rel = reliability(f);
    final double? sl = f?.slope;
    final cls = sl == null ? null : classOf(sl);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Band(
          hillAt: const Alignment(-1.0, -0.9),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Slope result', style: T.title(p.bandInk)),
                          Text(s.site.isEmpty ? s.name : '${s.name} · ${s.site}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small(p.bandMuted)),
                        ],
                      ),
                    ),
                    if (rel != null)
                      Chip2(
                        text: rel.label,
                        filled: true,
                        color: switch (rel) {
                          Rel.good => p.bandGood,
                          Rel.fair => p.bandWarn,
                          _ => p.bandBad,
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClassDial(slope: sl),
                const SizedBox(height: 6),
                if (f != null && sl != null) ...[
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: sl.abs()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text.rich(
                        TextSpan(children: [
                          TextSpan(text: v.toStringAsFixed(2), style: T.hero(p.bandInk)),
                          TextSpan(text: ' %', style: T.big(p.bandMuted).copyWith(fontSize: 24)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '${fx(slopeDegrees(sl), 2)}°  ·  ${oneIn(sl)}  ·  ± ${fx(f.unc, 2)} %',
                      style: T.num(p.bandInk, size: 16, w: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      '${f.dh < 0 ? 'Falls' : 'Rises'} from ${r.rows.first.point.label} to ${r.rows.last.point.label}',
                      style: T.small(p.bandMuted),
                    ),
                  ),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        r.skipped > 0
                            ? 'Record at least two points with elevation. ${r.skipped} point(s) have no elevation yet.'
                            : 'Record at least two points to see the slope.',
                        textAlign: TextAlign.center,
                        style: T.body(p.bandInk),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Slider3<Method>(
                  values: Method.values,
                  labels: Method.values.map((m) => m.short).toList(),
                  value: method,
                  enabled: [true, r.fit != null, true],
                  onChanged: state.setMethod,
                  onBand: true,
                ),
              ],
            ),
          ),
        ),
        if (f != null && cls != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Stagger(
              index: 0,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Stat(label: 'Horiz. distance', value: '${fx(f.dist, 1)} m')),
                        Expanded(child: Stat(label: 'Height diff.', value: '${signed(f.dh, 2)} m')),
                        Expanded(
                            child: Stat(label: 'Points', value: '${r.n}${r.skipped > 0 ? ' (+${r.skipped})' : ''}')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: classColors[slopeClasses.indexOf(cls)],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(cls.code, style: T.big(const Color(0xFF14201A)).copyWith(fontSize: 30)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Class ${cls.code} · ${cls.name}', style: T.head(p.ink)),
                              Text(cls.range, style: T.num(p.muted, size: 13.5, w: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(cls.treatment, style: T.body(p.ink)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_methodNote(method, r), style: T.small(p.muted)),
                  ],
                ),
              ),
            ),
          ),
          if (rel == Rel.bad || rel == Rel.close)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.bad.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.bad),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: p.bad),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rel == Rel.close
                            ? 'The points are less than 10 m apart. Spread them further apart along the slope.'
                            : 'The GPS height error (±${fx(f.unc, 1)} %) is too large for this slope over ${fx(f.dist, 0)} m. '
                                'Spread the points further apart, or type RLs from an auto level into the points.',
                        style: T.body(p.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Stagger(
            index: 1,
            child: Panel(
              title: 'Ground profile',
              trailing: Text('elevation vs chainage', style: T.small(p.muted)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileChart(result: r),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      _Legend(color: p.field, text: 'Measured'),
                      if (r.fit != null) _Legend(color: p.amber, text: 'Best-fit line', dashed: true),
                      _Legend(color: p.muted, text: 'Bars = ± vertical accuracy', bar: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Stagger(
            index: 2,
            child: Panel(
              title: 'Plan view',
              trailing: Text('north up', style: T.small(p.muted)),
              child: PlanView(points: s.points),
            ),
          ),
        ),
        if (r.ok)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Stagger(index: 3, child: Panel(title: 'Segment table', child: _SegTable(r: r))),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Stagger(
            index: 4,
            child: Panel(
              title: 'Share',
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: WideButton(
                        icon: Icons.table_chart_rounded,
                        label: 'CSV for Excel',
                        onTap: () => _guard(context, () => shareFile(s, 'csv', csvText(s), 'text/csv')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WideButton(
                        icon: Icons.public_rounded,
                        label: 'KML for Google Earth',
                        onTap: () => _guard(
                            context, () => shareFile(s, 'kml', kmlText(s), 'application/vnd.google-earth.kml+xml')),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: WideButton(
                        icon: Icons.chat_rounded,
                        label: 'Share summary',
                        primary: true,
                        onTap: () => _guard(context, () => shareText(summaryText(s, method), '${s.name} – slope')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WideButton(
                        icon: Icons.copy_rounded,
                        label: 'Copy summary',
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: summaryText(s, method)));
                          if (context.mounted) toast(context, 'Summary copied');
                        },
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  static Future<void> _guard(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) toast(context, 'Could not share: $e');
    }
  }

  static String _methodNote(Method m, SlopeResult r) => switch (m) {
        Method.fit =>
          'Best fit: a straight line through all ${r.n} points against chainage (R² ${fx(r.fit?.r2, 2)}). Best when you record several points along one line.',
        Method.route => 'Along route: height difference between the first and last point divided by the walked distance.',
        Method.e2e =>
          'End to end: height difference between the first and last point divided by the straight distance between them.',
      };
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text, this.dashed = false, this.bar = false});
  final Color color;
  final String text;
  final bool dashed, bar;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bar)
          Container(width: 2, height: 14, color: color)
        else if (dashed)
          Row(children: [
            Container(width: 7, height: 3, color: color),
            const SizedBox(width: 3),
            Container(width: 7, height: 3, color: color),
          ])
        else
          Container(width: 18, height: 3, color: color),
        const SizedBox(width: 6),
        Text(text, style: T.small(p.muted)),
      ],
    );
  }
}

class _SegTable extends StatelessWidget {
  const _SegTable({required this.r});
  final SlopeResult r;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final head = T.label(p.muted).copyWith(fontSize: 11);
    final cell = T.num(p.ink, size: 14, w: FontWeight.w500);
    final bold = T.num(p.ink, size: 14, w: FontWeight.w700);
    Widget c(String t, TextStyle st, {bool left = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(t, style: st, textAlign: left ? TextAlign.left : TextAlign.right),
        );
    final rows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
        children: [
          c('POINT', head, left: true),
          c('ELEV. M', head),
          c('±M', head),
          c('CHAIN. M', head),
          c('DIST M', head),
          c('ΔH M', head),
          c('SLOPE %', head),
        ],
      ),
      for (final (i, e) in r.rows.indexed)
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line.withOpacity(0.6)))),
          children: [
            c(e.point.label, bold, left: true),
            c(fx(e.elev, 2), cell),
            c(e.point.hasRL ? 'RL' : fx(e.sigma, 1), cell),
            c(fx(e.chainage, 1), cell),
            c(i == 0 ? '' : fx(e.dist, 1), cell),
            c(i == 0 ? '' : signed(e.dh, 2), cell),
            c(i == 0 || e.slope == null ? '' : signed(e.slope, 2), bold),
          ],
        ),
      for (final f in r.all)
        TableRow(
          decoration: BoxDecoration(color: p.fieldSoft),
          children: [
            c(f.method.label, bold, left: true),
            c('', cell),
            c('', cell),
            c('', cell),
            c(fx(f.dist, 1), cell),
            c(signed(f.dh, 2), cell),
            c('${signed(f.slope, 2)} ±${fx(f.unc, 2)}', bold),
          ],
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }
}
