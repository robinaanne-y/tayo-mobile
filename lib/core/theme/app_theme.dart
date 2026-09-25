import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_color_tokens.dart';
import 'app_radius.dart';

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

    // Headings use Nunito Semibold (matches h1-h5 in the reference
    // stylesheet); everything else stays Inter, per the design system's
    // "Display/H1/H2/H3" (Nunito) vs "Body/Small/Label/Button" (Inter)
    // split.
    final headingStyle = GoogleFonts.nunito(
      fontWeight: FontWeight.w600,
      color: tokens.textPrimary,
    );
    final h3Style = headingStyle.copyWith(fontSize: 18, height: 24 / 18);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      extensions: [tokens],
      textTheme: baseTextTheme.copyWith(
        // Display 30/38 — onboarding headline.
        displayLarge: headingStyle.copyWith(fontSize: 30, height: 38 / 30),
        // H1 26/34 — main screen title.
        headlineSmall: headingStyle.copyWith(fontSize: 26, height: 34 / 26),
        // H2 22/28 — major section / sheet & dialog title.
        titleLarge: headingStyle.copyWith(fontSize: 22, height: 28 / 22),
        // H3 18/24 — card title / section header.
        titleMedium: h3Style,
        // Body 16/24 regular.
        bodyMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 16,
          height: 24 / 16,
          color: tokens.textPrimary,
        ),
        // Small 14/20 regular — supporting/secondary text.
        bodySmall: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 20 / 14,
          color: tokens.textSecondary,
        ),
        // Label 12/16 medium — chips, timestamps.
        labelMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          height: 16 / 12,
          color: tokens.textSecondary,
        ),
        // Button 15/20 semibold — drives every ButtonStyleButton's default
        // label style (Elevated/Outlined/Text) since none of them override
        // `textStyle` explicitly below.
        labelLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          height: 20 / 15,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: h3Style,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: tokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
