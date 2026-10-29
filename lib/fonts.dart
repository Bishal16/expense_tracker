import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Direct references to just the fonts we offer. Looking fonts up by name
// (GoogleFonts.getFont) pulls every Google Font into the app, ~30 MB extra.

typedef _Font = TextStyle Function({double? fontSize, FontWeight? fontWeight});
typedef _Theme = TextTheme Function([TextTheme? textTheme]);

const Map<String, _Font> _fonts = {
  'Quicksand': GoogleFonts.quicksand,
  'Nunito': GoogleFonts.nunito,
  'Poppins': GoogleFonts.poppins,
  'Comfortaa': GoogleFonts.comfortaa,
  'Fredoka': GoogleFonts.fredoka,
  'Lora': GoogleFonts.lora,
  'Playfair Display': GoogleFonts.playfairDisplay,
  'Manrope': GoogleFonts.manrope,
  'Dancing Script': GoogleFonts.dancingScript,
  'Great Vibes': GoogleFonts.greatVibes,
  'Pacifico': GoogleFonts.pacifico,
  'Satisfy': GoogleFonts.satisfy,
  'Sacramento': GoogleFonts.sacramento,
  'Caveat': GoogleFonts.caveat,
};

const Map<String, _Theme> _themes = {
  'Quicksand': GoogleFonts.quicksandTextTheme,
  'Nunito': GoogleFonts.nunitoTextTheme,
  'Poppins': GoogleFonts.poppinsTextTheme,
  'Comfortaa': GoogleFonts.comfortaaTextTheme,
  'Fredoka': GoogleFonts.fredokaTextTheme,
  'Lora': GoogleFonts.loraTextTheme,
  'Playfair Display': GoogleFonts.playfairDisplayTextTheme,
  'Manrope': GoogleFonts.manropeTextTheme,
};

TextStyle fontStyle(
  String family, {
  double? fontSize,
  FontWeight? fontWeight,
}) => (_fonts[family] ?? GoogleFonts.manrope)(
  fontSize: fontSize,
  fontWeight: fontWeight,
);

TextTheme fontTextTheme(String family, TextTheme base) =>
    (_themes[family] ?? GoogleFonts.manropeTextTheme)(base);
