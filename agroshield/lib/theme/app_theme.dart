import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ───────────────────────────────────────────────────────────
  static const Color bg         = Color(0xFF0B1A0D);
  static const Color bgNav      = Color(0xFF111F12);
  static const Color bgTopBar   = Color(0xFF1A3D1F);
  static const Color accent     = Color(0xFF6FCF80);
  static const Color accentDark = Color(0xFF43A853);

  // Text — hex equivalents for withValues(alpha:) so they can be const
  static const Color textPrimary = Colors.white;
  static const Color textSub     = Color(0xB3FFFFFF); // 70% white
  static const Color textMuted   = Color(0x73FFFFFF); // 45% white

  // Alert colours
  static const Color amberStrip  = Color(0x1AEF9E27); // 10% amber bg
  static const Color amberBorder = Color(0x33EF9E27); // 20% amber border
  static const Color amberText   = Color(0xFFEF9E27);
  static const Color dangerRed   = Color(0xFFE24B4A);

  // Frosted card — hex equivalents
  static const Color _frostedStart  = Color(0x2E6FCF80); // #6fcf80 @ 18%
  static const Color _frostedEnd    = Color(0x1A43A853); // #43a853 @ 10%
  static const Color _frostedBorder = Color(0x406FCF80); // #6fcf80 @ 25%

  // ── Typography helpers ────────────────────────────────────────────────
  static TextStyle headline(double size) => GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: size * -0.02,
      );

  static TextStyle body(double size,
      {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textPrimary,
      );

  // ── Frosted card decoration ───────────────────────────────────────────
  static BoxDecoration frostedCard({double radius = 14}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_frostedStart, _frostedEnd],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _frostedBorder),
      );

  // ── ThemeData ─────────────────────────────────────────────────────────
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentDark,
        surface: bgNav,
        error: dangerRed,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        headlineLarge: headline(28),
        headlineMedium: headline(22),
        titleLarge: headline(18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: bg,
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(
              fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x146FCF80), // 8% accent
        hintStyle: GoogleFonts.dmSans(
            color: textMuted, fontSize: 15),
        prefixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x266FCF80)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x266FCF80)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: const Color(0x336FCF80),
        thumbColor: accent,
        overlayColor: const Color(0x266FCF80),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
      ),
      dividerColor: const Color(0x1AFFFFFF),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: accent),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: textSub),
      ),
    );
  }
}

// ── Shared frosted-glass card widget ──────────────────────────────────────
//
// PERF: BackdropFilter with ImageFilter.blur is expensive on budget Android
// (think Ramesh's ₹8,000 phone). If lag is noticed, change sigmaX/sigmaY to
// 0 — the gradient + border still look good without the blur.
class FrostedCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  const FrostedCard({
    super.key,
    required this.child,
    this.radius = 14,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: AppTheme.frostedCard(radius: radius),
          child: child,
        ),
      ),
    );
  }
}
