import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/slope.dart';
import '../core/store.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import 'result_screen.dart';
import 'survey_screen.dart';
import 'surveys_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, this.startTab = 0});
  final int startTab;

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  late int tab = widget.startTab;

  void go(int i) {
    if (i == tab) return;
    HapticFeedback.selectionClick();
    setState(() => tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pages = [
      SurveyScreen(onShowResult: () => go(1), onOpenSurveys: () => go(2)),
      const ResultScreen(),
      SurveysScreen(onOpened: () => go(0)),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: p.surface,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.025), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
        ),
        bottomNavigationBar: _NavBar(tab: tab, onTap: go),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.tab, required this.onTap});
  final int tab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final state = context.watch<AppState>();
    final r = computeSlope(state.current.points);
    final items = [
      (NavGlyph.survey, 'Survey', state.current.points.isEmpty ? null : '${state.current.points.length}'),
      (NavGlyph.result, 'Result', r.ok ? '${fx(r.by(state.method)!.slope?.abs(), 1)}%' : null),
      (NavGlyph.surveys, 'Surveys', null),
    ];
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              for (final (i, it) in items.indexed)
                Expanded(
                  flex: i == tab ? 14 : 10,
                  child: _NavItem(
                    glyph: it.$1,
                    label: it.$2,
                    badge: it.$3,
                    selected: i == tab,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.glyph, required this.label, required this.selected, required this.onTap, this.badge});
  final NavGlyph glyph;
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = selected ? p.amberInk : p.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? p.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NavIcon(glyph: glyph, selected: selected, color: fg),
              Flexible(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(label,
                              maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: T.head(fg)),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              if (!selected && badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: p.fieldSoft, borderRadius: BorderRadius.circular(8)),
                  child: Text(badge!, style: T.num(p.field, size: 12, w: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
