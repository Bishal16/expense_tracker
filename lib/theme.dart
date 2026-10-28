import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart';

/// Per-user look: colors, gradients and decorative touches.
@immutable
class AppStyle extends ThemeExtension<AppStyle> {
  final Color seed;
  final Color accent;
  final List<Color> header;
  final List<Color> background;
  final Color cardShadow;
  final IconData motif;
  final String emoji;
  final bool playful;

  const AppStyle({
    required this.seed,
    required this.accent,
    required this.header,
    required this.background,
    required this.cardShadow,
    required this.motif,
    required this.emoji,
    required this.playful,
  });

  /// Admin: deep navy to teal, crisp and businesslike.
  static const admin = AppStyle(
    seed: Color(0xFF1E3A8A),
    accent: Color(0xFF0F766E),
    header: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0F766E)],
    background: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
    cardShadow: Color(0x1A1E3A8A),
    motif: Icons.insights_rounded,
    emoji: '💼',
    playful: false,
  );

  /// User 1: blush rose to lavender, soft and friendly.
  static const blossom = AppStyle(
    seed: Color(0xFFDB2777),
    accent: Color(0xFFDB2777),
    header: [Color(0xFFF9A8D4), Color(0xFFF472B6), Color(0xFFC084FC)],
    background: [Color(0xFFFFF1F6), Color(0xFFF8F0FF)],
    cardShadow: Color(0x22DB2777),
    motif: Icons.local_florist_rounded,
    emoji: '🌸',
    playful: true,
  );

  /// Login screen, before we know who is signing in.
  static const welcome = AppStyle(
    seed: Color(0xFF6D28D9),
    accent: Color(0xFF7C3AED),
    header: [Color(0xFF1E3A8A), Color(0xFF7C3AED), Color(0xFFEC4899)],
    background: [Color(0xFFF5F3FF), Color(0xFFFFF1F6)],
    cardShadow: Color(0x1A7C3AED),
    motif: Icons.account_balance_wallet_rounded,
    emoji: '✨',
    playful: false,
  );

  static AppStyle forEmail(String? email) {
    if (email == null) return welcome;
    return isAdminEmail(email) ? admin : blossom;
  }

  LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: header,
  );

  LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: background,
  );

  /// Display font for big greetings.
  TextStyle greeting(double size) => playful
      ? GoogleFonts.dancingScript(fontSize: size, fontWeight: FontWeight.w700)
      : GoogleFonts.manrope(fontSize: size, fontWeight: FontWeight.w800);

  ThemeData get theme {
    final scheme = ColorScheme.fromSeed(seedColor: seed, primary: accent);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = playful
        ? GoogleFonts.quicksandTextTheme(base.textTheme)
        : GoogleFonts.manropeTextTheme(base.textTheme);
    final radius = playful ? 24.0 : 18.0;
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: background.first,
      extensions: [this],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.primary.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.primary.withValues(alpha: 0.08),
        selectedColor: scheme.primary,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: Colors.white),
        checkmarkColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: header.length > 1 ? header[1] : accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  AppStyle copyWith() => this;

  @override
  AppStyle lerp(AppStyle? other, double t) => t < 0.5 ? this : other ?? this;
}

extension AppStyleContext on BuildContext {
  AppStyle get style =>
      Theme.of(this).extension<AppStyle>() ?? AppStyle.welcome;
}
