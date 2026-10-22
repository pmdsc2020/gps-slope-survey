import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/gps.dart';
import 'core/store.dart';
import 'screens/shell.dart';
import 'screens/splash.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  await state.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<GpsService>(create: (_) => GpsService()),
      ],
      child: const SlopeApp(),
    ),
  );
}

class SlopeApp extends StatelessWidget {
  const SlopeApp({super.key, this.splash = true, this.themeOverride, this.startTab = 0});
  final bool splash;
  final ThemeMode? themeOverride;
  final int startTab;

  @override
  Widget build(BuildContext context) {
    final mode = themeOverride ?? context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'GPS Slope Survey',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      home: splash ? const SplashScreen() : Shell(startTab: startTab),
    );
  }
}
