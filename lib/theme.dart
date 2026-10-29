import 'package:flutter/material.dart';

import 'config.dart';
import 'fonts.dart';
import 'models/theme_prefs.dart';

/// Per-user look, built from the user's saved [ThemePrefs].
@immutable
class AppStyle extends ThemeExtension<AppStyle> {
  final ThemePrefs prefs;
  final Palette palette;

  /// Shown in the greeting; null means "work it out from the email".
  final String? displayName;

  const AppStyle._(this.prefs, this.palette, this.displayName);

  factory AppStyle.fromPrefs(ThemePrefs prefs) =>
      AppStyle._(prefs, Palette.byId(prefs.palette), prefs.displayName);

  /// The signed-in user's style: their saved prefs, or their role's defaults.
  factory AppStyle.resolve(String? email, ThemePrefs? saved) {
    if (email == null) return welcome;
    return AppStyle.fromPrefs(
      saved ?? ThemePrefs.defaults(admin: isAdminEmail(email)),
    );
  }

  /// Default look for [email], e.g. for saved-account cards on the login page.
  factory AppStyle.forEmail(String? email) => AppStyle.resolve(email, null);

  /// Login screen, before we know who is signing in.
  static final welcome = AppStyle._(
    const ThemePrefs(
      palette: 'welcome',
      bodyFont: 'Manrope',
      greetingFont: 'Manrope',
      emoji: '✨',
      motif: 'insights',
      radius: 18,
      textScale: 1,
      decorations: false,
    ),
    const Palette(
      'welcome',
      'Welcome',
      Color(0xFF7C3AED),
      [Color(0xFF1E3A8A), Color(0xFF7C3AED), Color(0xFFEC4899)],
      [Color(0xFFF5F3FF), Color(0xFFFFF1F6)],
    ),
    null,
  );

  Color get accent => palette.accent;
  List<Color> get header => palette.header;
  List<Color> get background => palette.background;
  Color get cardShadow => accent.withValues(alpha: 0.13);
  IconData get motif => motifs[prefs.motif] ?? Icons.auto_awesome_rounded;
  String get emoji => prefs.emoji;
  double get radius => prefs.radius;

  /// Extra hearts and sweeter wording.
  bool get playful => prefs.decorations;

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

  /// Display font for greetings and titles. Script fonts are scaled up so
  /// every choice reads at about the same size.
  TextStyle greeting(double size) {
    final font = prefs.greetingFont;
    final script = greetingFontScale[font];
    return fontStyle(
      font,
      fontSize: size * (script ?? 1),
      fontWeight: switch (font) {
        'Manrope' => FontWeight.w800,
        'Playfair Display' || 'Dancing Script' || 'Caveat' => FontWeight.w700,
        _ => FontWeight.w400,
      },
    );
  }

  ThemeData get theme {
    final scheme = ColorScheme.fromSeed(seedColor: accent, primary: accent);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = fontTextTheme(prefs.bodyFont, base.textTheme);
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
