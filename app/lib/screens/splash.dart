import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/contours.dart';
import '../ui/logo.dart';
import '../ui/theme.dart';
import 'shell.dart';

/// The logo builds itself, then the app opens.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const Shell(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: p.band,
        body: Band(
          hillAt: const Alignment(0, -0.15),
          child: SizedBox.expand(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final title = Curves.easeOut.transform(((t - 0.6) / 0.4).clamp(0.0, 1.0));
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LogoMark(size: 148, t: t),
                    const SizedBox(height: 28),
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - title)),
                        child: Column(
                          children: [
                            Text('GPS Slope Survey', style: T.big(p.bandInk).copyWith(fontSize: 32)),
                            const SizedBox(height: 6),
                            Text('Land slope from phone GPS  ·  जमिनीचा उतार', style: T.body(p.bandMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
