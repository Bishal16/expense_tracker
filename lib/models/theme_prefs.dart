import 'package:flutter/material.dart';

/// A named color scheme: header gradient, page background and accent.
class Palette {
  final String id;
  final String name;
  final Color accent;
  final List<Color> header;
  final List<Color> background;

  const Palette(this.id, this.name, this.accent, this.header, this.background);

  static const all = [
    Palette(
      'blossom',
      'Blossom',
      Color(0xFFDB2777),
      [Color(0xFFF9A8D4), Color(0xFFF472B6), Color(0xFFC084FC)],
      [Color(0xFFFFF1F6), Color(0xFFF8F0FF)],
    ),
    Palette(
      'rosegold',
      'Rose Gold',
      Color(0xFFA8506A),
      [Color(0xFFF2B8B5), Color(0xFFD98C99), Color(0xFFB76E79)],
      [Color(0xFFFFF5F4), Color(0xFFFCEEF1)],
    ),
    Palette(
      'berry',
      'Berry Kiss',
      Color(0xFFBE185D),
      [Color(0xFFF472B6), Color(0xFFDB2777), Color(0xFF9D174D)],
      [Color(0xFFFDF2F8), Color(0xFFFCE7F3)],
    ),
    Palette(
      'lavender',
      'Lavender Dream',
      Color(0xFF7C3AED),
      [Color(0xFFC4B5FD), Color(0xFFA78BFA), Color(0xFF818CF8)],
      [Color(0xFFF5F3FF), Color(0xFFEEF2FF)],
    ),
    Palette(
      'peach',
      'Peach Sunset',
      Color(0xFFE2553D),
      [Color(0xFFFDBA74), Color(0xFFFB923C), Color(0xFFF472B6)],
      [Color(0xFFFFF7ED), Color(0xFFFFF1F2)],
    ),
    Palette(
      'golden',
      'Golden Hour',
      Color(0xFFD97706),
      [Color(0xFFFCD34D), Color(0xFFF59E0B), Color(0xFFF43F5E)],
      [Color(0xFFFFFBEB), Color(0xFFFFF1F2)],
    ),
    Palette(
      'mint',
      'Mint Breeze',
      Color(0xFF0D9488),
      [Color(0xFF5EEAD4), Color(0xFF14B8A6), Color(0xFF0D9488)],
      [Color(0xFFF0FDFA), Color(0xFFECFEFF)],
    ),
    Palette(
      'ocean',
      'Ocean',
      Color(0xFF0284C7),
      [Color(0xFF7DD3FC), Color(0xFF38BDF8), Color(0xFF6366F1)],
      [Color(0xFFF0F9FF), Color(0xFFEEF2FF)],
    ),
    Palette(
      'midnight',
      'Midnight',
      Color(0xFF0F766E),
      [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0F766E)],
      [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
    ),
  ];

  static Palette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

/// Fonts offered in settings. Script fonts render small, so they get scaled.
const bodyFonts = [
  'Quicksand',
  'Nunito',
  'Poppins',
  'Comfortaa',
  'Fredoka',
  'Lora',
  'Playfair Display',
  'Manrope',
];

const greetingFonts = [
  'Dancing Script',
  'Great Vibes',
  'Pacifico',
  'Satisfy',
  'Sacramento',
  'Caveat',
  'Playfair Display',
  'Manrope',
];

const greetingFontScale = {
  'Dancing Script': 1.3,
  'Great Vibes': 1.35,
  'Satisfy': 1.25,
  'Sacramento': 1.5,
  'Caveat': 1.3,
};

const emojis = ['🌸', '🌷', '🦋', '💖', '🎀', '✨', '🌙', '🍓', '🌼', '☕', '💼'];

const motifs = <String, IconData>{
  'flower': Icons.local_florist_rounded,
  'spa': Icons.spa_rounded,
  'heart': Icons.favorite_rounded,
  'sparkle': Icons.auto_awesome_rounded,
  'leaf': Icons.eco_rounded,
  'sun': Icons.wb_sunny_rounded,
  'moon': Icons.nightlight_round,
  'paw': Icons.pets_rounded,
  'diamond': Icons.diamond_rounded,
  'insights': Icons.insights_rounded,
};

const cornerStyles = {
  'Crisp': 12.0,
  'Soft': 18.0,
  'Round': 24.0,
  'Bubbly': 32.0,
};

/// One user's look, stored in prefs/{uid}.
@immutable
class ThemePrefs {
  final String palette;
  final String bodyFont;
  final String greetingFont;
  final String emoji;
  final String motif;
  final double radius;
  final double textScale;
  final bool decorations;
  final String? displayName;

  const ThemePrefs({
    required this.palette,
    required this.bodyFont,
    required this.greetingFont,
    required this.emoji,
    required this.motif,
    required this.radius,
    required this.textScale,
    required this.decorations,
    this.displayName,
  });

  /// Admin starts businesslike; everyone else starts soft and pink.
  factory ThemePrefs.defaults({required bool admin}) => admin
      ? const ThemePrefs(
          palette: 'midnight',
          bodyFont: 'Manrope',
          greetingFont: 'Manrope',
          emoji: '💼',
          motif: 'insights',
          radius: 18,
          textScale: 1,
          decorations: false,
        )
      : const ThemePrefs(
          palette: 'blossom',
          bodyFont: 'Quicksand',
          greetingFont: 'Dancing Script',
          emoji: '🌸',
          motif: 'flower',
          radius: 24,
          textScale: 1,
          decorations: true,
        );

  /// Reads a stored map, falling back to [base] for anything missing or
  /// no longer offered.
  factory ThemePrefs.fromMap(Map<String, dynamic> m, ThemePrefs base) {
    T pick<T>(String key, T fallback, [bool Function(T)? valid]) {
      final v = m[key];
      return v is T && (valid == null || valid(v)) ? v : fallback;
    }

    return ThemePrefs(
      palette: pick('palette', base.palette, (String v) {
        return Palette.all.any((p) => p.id == v);
      }),
      bodyFont: pick('bodyFont', base.bodyFont, bodyFonts.contains),
      greetingFont: pick(
        'greetingFont',
        base.greetingFont,
        greetingFonts.contains,
      ),
      emoji: pick('emoji', base.emoji),
      motif: pick('motif', base.motif, motifs.containsKey),
      radius: (m['radius'] as num?)?.toDouble() ?? base.radius,
      textScale: ((m['textScale'] as num?)?.toDouble() ?? base.textScale).clamp(
        0.85,
        1.3,
      ),
      decorations: pick('decorations', base.decorations),
      displayName: (m['displayName'] as String?)?.trim().isEmpty ?? true
          ? null
          : (m['displayName'] as String).trim(),
    );
  }

  Map<String, dynamic> toMap() => {
    'palette': palette,
    'bodyFont': bodyFont,
    'greetingFont': greetingFont,
    'emoji': emoji,
    'motif': motif,
    'radius': radius,
    'textScale': textScale,
    'decorations': decorations,
    'displayName': displayName,
  };

  ThemePrefs copyWith({
    String? palette,
    String? bodyFont,
    String? greetingFont,
    String? emoji,
    String? motif,
    double? radius,
    double? textScale,
    bool? decorations,
    String? displayName,
    bool clearName = false,
  }) => ThemePrefs(
    palette: palette ?? this.palette,
    bodyFont: bodyFont ?? this.bodyFont,
    greetingFont: greetingFont ?? this.greetingFont,
    emoji: emoji ?? this.emoji,
    motif: motif ?? this.motif,
    radius: radius ?? this.radius,
    textScale: textScale ?? this.textScale,
    decorations: decorations ?? this.decorations,
    displayName: clearName ? null : displayName ?? this.displayName,
  );
}
