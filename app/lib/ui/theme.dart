import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';

/// Ambient (looping) animations. Tests switch this off so frames can settle.
class Motion {
  static bool ambient = true;
}

/// Colour tokens. "band" is the dark instrument panel at the top of each screen.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.band,
    required this.bandInk,
    required this.bandMuted,
    required this.contour,
    required this.field,
    required this.fieldSoft,
    required this.amber,
    required this.amberInk,
    required this.good,
    required this.warn,
    required this.bad,
  });

  final Color bg, surface, raised, ink, muted, line;
  final Color band, bandInk, bandMuted, contour;
  final Color field, fieldSoft, amber, amberInk;
  final Color good, warn, bad;

  static const light = Palette(
    bg: Color(0xFFEDF1EB),
    surface: Color(0xFFF8FAF6),
    raised: Color(0xFFFFFFFF),
    ink: Color(0xFF15201A),
    muted: Color(0xFF56665C),
    line: Color(0xFFCDD6CB),
    band: Color(0xFF123F30),
    bandInk: Color(0xFFEDF4EE),
    bandMuted: Color(0xFFA6C1B2),
    contour: Color(0xFF2E6E53),
    field: Color(0xFF1E6A4D),
    fieldSoft: Color(0x1F1E6A4D),
    amber: Color(0xFFF2B31B),
    amberInk: Color(0xFF1B1505),
    good: Color(0xFF2D7A4E),
    warn: Color(0xFFA86A12),
    bad: Color(0xFFB83A2E),
  );

  static const dark = Palette(
    bg: Color(0xFF0C1310),
    surface: Color(0xFF141C18),
    raised: Color(0xFF1B2520),
    ink: Color(0xFFE3EAE2),
    muted: Color(0xFF95A599),
    line: Color(0xFF28352E),
    band: Color(0xFF0A2219),
    bandInk: Color(0xFFE6EEE7),
    bandMuted: Color(0xFF8EA898),
    contour: Color(0xFF1C4A38),
    field: Color(0xFF7FC79F),
    fieldSoft: Color(0x247FC79F),
    amber: Color(0xFFF2B31B),
    amberInk: Color(0xFF1B1505),
    good: Color(0xFF5FC58B),
    warn: Color(0xFFE5A940),
    bad: Color(0xFFEE6B5D),
  );

  /// Band colours stay the same in both themes' semantic roles but band text needs
  /// its own good/warn/bad that read on the dark band.
  Color get bandGood => const Color(0xFF7BD9A2);
  Color get bandWarn => const Color(0xFFF5C451);
  Color get bandBad => const Color(0xFFFF8A7A);

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      raised: c(raised, other.raised),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      line: c(line, other.line),
      band: c(band, other.band),
      bandInk: c(bandInk, other.bandInk),
      bandMuted: c(bandMuted, other.bandMuted),
      contour: c(contour, other.contour),
      field: c(field, other.field),
      fieldSoft: c(fieldSoft, other.fieldSoft),
      amber: c(amber, other.amber),
      amberInk: c(amberInk, other.amberInk),
      good: c(good, other.good),
      warn: c(warn, other.warn),
      bad: c(bad, other.bad),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

const String kFont = 'BarlowSC';
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

/// Type scale.
class T {
  static TextStyle hero(Color c) => TextStyle(
      fontFamily: kFont, fontSize: 56, height: 0.95, fontWeight: FontWeight.w700, color: c, fontFeatures: kTabular);
  static TextStyle big(Color c) => TextStyle(
      fontFamily: kFont, fontSize: 34, height: 1.0, fontWeight: FontWeight.w700, color: c, fontFeatures: kTabular);
  static TextStyle title(Color c) =>
      TextStyle(fontFamily: kFont, fontSize: 20, height: 1.15, fontWeight: FontWeight.w700, color: c);
  static TextStyle head(Color c) =>
      TextStyle(fontFamily: kFont, fontSize: 17, height: 1.2, fontWeight: FontWeight.w600, color: c);
  static TextStyle body(Color c) => TextStyle(fontFamily: kFont, fontSize: 15.5, height: 1.35, color: c);
  static TextStyle small(Color c) => TextStyle(fontFamily: kFont, fontSize: 13.5, height: 1.3, color: c);
  static TextStyle num(Color c, {double size = 16, FontWeight w = FontWeight.w600}) =>
      TextStyle(fontFamily: kFont, fontSize: size, fontWeight: w, color: c, fontFeatures: kTabular, height: 1.15);
  static TextStyle label(Color c) => TextStyle(
      fontFamily: kFont, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: c, height: 1.2);
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1E6A4D), brightness: b).copyWith(
    primary: p.field,
    onPrimary: b == Brightness.dark ? const Color(0xFF07140E) : Colors.white,
    secondary: p.amber,
    onSecondary: p.amberInk,
    surface: p.surface,
    onSurface: p.ink,
    error: p.bad,
    outline: p.line,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: p.line),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    fontFamily: kFont,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .englishLike
        .apply(fontFamily: kFont, bodyColor: p.ink, displayColor: p.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.raised,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: T.body(p.muted),
      floatingLabelStyle: T.small(p.field),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: p.amber, width: 2)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: T.body(p.bg),
      actionTextColor: p.amber,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.line,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: T.title(p.ink),
      contentTextStyle: T.body(p.ink),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
  );
}

double lerpD(double a, double b, double t) => lerpDouble(a, b, t)!;
