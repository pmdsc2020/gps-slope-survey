import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Segmented control with a thumb that slides to the chosen option.
class Slider3<V> extends StatelessWidget {
  const Slider3({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.onBand = false,
    this.enabled,
  });
  final List<V> values;
  final List<String> labels;
  final V value;
  final ValueChanged<V> onChanged;
  final bool onBand;
  final List<bool>? enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final idx = values.indexOf(value).clamp(0, values.length - 1);
    final track = onBand ? Colors.white.withOpacity(0.09) : p.raised;
    final border = onBand ? Colors.white.withOpacity(0.14) : p.line;
    final thumb = onBand ? p.amber : p.ink;
    final on = onBand ? p.amberInk : p.bg;
    final off = onBand ? p.bandInk : p.muted;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(values.length == 1 ? 0 : -1 + 2 * idx / (values.length - 1), 0),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            child: FractionallySizedBox(
              widthFactor: 1 / values.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: thumb, borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == idx,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: (enabled == null || enabled![i])
                          ? () {
                              HapticFeedback.selectionClick();
                              onChanged(values[i]);
                            }
                          : null,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: T.head(i == idx ? on : off).copyWith(
                                fontSize: 15,
                                color: (enabled == null || enabled![i]) ? null : off.withOpacity(0.35),
                              ),
                          child: Text(labels[i], maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Plain card on the page background.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.title, this.trailing});
  final Widget child;
  final EdgeInsets padding;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(child: Text(title!, style: T.title(p.ink).copyWith(fontSize: 18))),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Small uppercase label.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: T.label(color ?? context.pal.muted));
}

/// Coloured status chip.
class Chip2 extends StatelessWidget {
  const Chip2({super.key, required this.text, required this.color, this.filled = false, this.icon});
  final String text;
  final Color color;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(filled ? 1 : 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? p.bg : color),
            const SizedBox(width: 4),
          ],
          Text(text.toUpperCase(),
              style: T.label(filled ? (color.computeLuminance() > 0.5 ? p.amberInk : Colors.white) : color)
                  .copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// Label + value, used in rows of figures.
class Stat extends StatelessWidget {
  const Stat({super.key, required this.label, required this.value, this.color, this.labelColor, this.size = 19});
  final String label;
  final String value;
  final Color? color;
  final Color? labelColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(),
            style: T.label(labelColor ?? p.muted).copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: T.num(color ?? p.ink, size: size)),
        ),
      ],
    );
  }
}

/// Wide button with an icon, used for exports and main actions.
class WideButton extends StatelessWidget {
  const WideButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bg = primary ? p.amber : p.raised;
    final fg = primary ? p.amberInk : (danger ? p.bad : p.ink);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary ? p.amber : p.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    style: T.head(fg).copyWith(fontSize: 15.5), maxLines: 2, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts children in, one after another.
class Stagger extends StatelessWidget {
  const Stagger({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + 70 * index.clamp(0, 8)),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}

void toast(BuildContext context, String text, {SnackBarAction? action}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(text), action: action, duration: const Duration(seconds: 3)));
}
