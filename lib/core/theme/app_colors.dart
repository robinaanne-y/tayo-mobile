import 'package:flutter/material.dart';

/// Warm, calm household palette. Colors are used purposefully — member
/// identification, categories, status and key actions — never all at once.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFF8F7F2);
  static const Color surface = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF8A8A8A);

  // Brand
  static const Color primary = Color(0xFF4FBDAD);
  static const Color accent = Color(0xFFE8897A);

  // Palette accents (member/category/status use)
  static const Color mint = primary;
  static const Color coral = accent;
  static const Color skyBlue = Color(0xFF5B9BD5);
  static const Color softYellow = Color(0xFFF5C066);
  static const Color lavender = Color(0xFF9B8EC4);

  static const Color border = Color(0xFFE5E2DA);
  static const Color danger = Color(0xFFD9695B);
  static const Color success = primary;

  /// Rotating palette for assigning a consistent color per household member.
  static const List<Color> memberPalette = [
    lavender,
    skyBlue,
    coral,
    mint,
    softYellow,
  ];

  static Color memberColor(int index) =>
      memberPalette[index % memberPalette.length];
}
