import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_color_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(AppColorTokens.light, Brightness.light);

  static ThemeData get dark => _build(AppColorTokens.dark, Brightness.dark);

  static ThemeData _build(AppColorTokens tokens, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.primary,
      brightness: brightness,
      surface: tokens.surface,
      error: tokens.error,
    );

    final baseTextTheme = brightness == Brightness.dark
        ? GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.interTextTheme();
    final headingStyle = GoogleFonts.nunito(
      fontWeight: FontWeight.w800,
      color: tokens.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      extensions: [tokens],
      textTheme: baseTextTheme.copyWith(
        titleLarge: headingStyle.copyWith(fontSize: 22),
        headlineSmall: headingStyle.copyWith(fontSize: 20),
        titleMedium: headingStyle.copyWith(fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: tokens.textPrimary),
        bodySmall: GoogleFonts.inter(color: tokens.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: headingStyle.copyWith(fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.primaryForeground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
