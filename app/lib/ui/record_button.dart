import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'theme.dart';

/// The big round capture button. While recording, the ring fills as readings are
/// averaged; when a point is saved a check mark draws itself in the centre.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.ready,
    required this.recording,
    required this.progress,
    required this.secondsLeft,
    required this.readings,
    required this.label,
    required this.savedTick,
    required this.onTap,
    this.size = 168,
  });

  final bool ready; // GPS has a fix
  final bool recording;
  final double progress;
  final int secondsLeft;
  final int readings;
  final String label;
  final int savedTick; // changes each time a point is saved
  final VoidCallback onTap;
  final double size;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> with TickerProviderStateMixin {
  late final AnimationController _done =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _down = false;

  void _syncBreath() {
    if (widget.ready && !widget.recording && Motion.ambient) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncBreath();
  }

  @override
  void didUpdateWidget(RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.savedTick != old.savedTick) {
      _done.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
    _syncBreath();
  }

  @override
  void dispose() {
    _done.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = widget.size;
    return Semantics(
      button: true,
      label: widget.recording ? 'Recording, ${widget.secondsLeft} seconds left' : 'Record point ${widget.label}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: const Duration(milliseconds: 120),
          child: SizedBox.square(
            dimension: s,
            child: AnimatedBuilder(
              animation: Listenable.merge([_done, _breath]),
              builder: (context, _) {
                final doneT = _done.value;
                final showDone = _done.isAnimating || (doneT > 0 && doneT < 1);
                return CustomPaint(
                  painter: _RingPainter(
                    track: p.line,
                    fill: p.amber,
                    progress: widget.recording ? widget.progress : 0,
                    halo: widget.ready && !widget.recording ? _breath.value : 0,
                    haloColor: p.amber,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: s * 0.76,
                      height: s * 0.76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: showDone ? p.field : (widget.ready || widget.recording ? p.amber : p.raised),
                        border: Border.all(color: widget.ready || widget.recording ? Colors.transparent : p.line, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.ready ? p.amber : p.ink).withOpacity(widget.ready ? 0.35 : 0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: showDone
                          ? CustomPaint(
                              painter: CheckPainter(
                                  Curves.easeOutCubic.transform((doneT * 2).clamp(0.0, 1.0)),
                                  Theme.of(context).brightness == Brightness.dark ? p.bg : Colors.white))
                          : _content(p),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(Palette p) {
    final ink = widget.ready || widget.recording ? p.amberInk : p.muted;
    if (widget.recording) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${widget.secondsLeft}', style: T.hero(ink).copyWith(fontSize: 46)),
          Text('s left', style: T.small(ink)),
          const SizedBox(height: 2),
          Text('${widget.readings} readings', style: T.num(ink, size: 13, w: FontWeight.w500)),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomPaint(size: const Size(30, 30), painter: _CrosshairPainter(ink)),
        const SizedBox(height: 6),
        Text(widget.ready ? 'RECORD' : 'START GPS', style: T.label(ink)),
        Text(widget.label, style: T.big(ink).copyWith(fontSize: 26)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.track, required this.fill, required this.progress, required this.halo, required this.haloColor});
  final Color track, fill, haloColor;
  final double progress, halo;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    if (halo > 0) {
      canvas.drawCircle(
          c,
          r - 4 + 6 * halo,
          Paint()
            ..color = haloColor.withOpacity(0.16 * (1 - halo) + 0.06)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10);
    }
    // tick marks round the ring, like a dial
    final tick = Paint()
      ..color = track
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = -math.pi / 2 + i / 60 * 2 * math.pi;
      final l = i % 5 == 0 ? 7.0 : 3.5;
      final d = Offset(math.cos(a), math.sin(a));
      final on = progress > 0 && i / 60 <= progress;
      canvas.drawLine(c + d * (r - l), c + d * r, on ? (Paint()
        ..color = fill
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round) : tick);
    }
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + 4),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.halo != halo || o.track != track || o.fill != fill;
}

class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r * 0.55, p);
    canvas.drawLine(c - Offset(r, 0), c - Offset(r * 0.3, 0), p);
    canvas.drawLine(c + Offset(r * 0.3, 0), c + Offset(r, 0), p);
    canvas.drawLine(c - Offset(0, r), c - Offset(0, r * 0.3), p);
    canvas.drawLine(c + Offset(0, r * 0.3), c + Offset(0, r), p);
    canvas.drawCircle(c, 2.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrosshairPainter o) => o.color != color;
}
