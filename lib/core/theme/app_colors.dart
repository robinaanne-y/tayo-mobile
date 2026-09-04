import 'package:flutter/material.dart';

/// Warm, calm household palette. Colors are used purposefully — member
/// identification, categories, status and key actions — never all at once.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFFBF8F3);
  static const Color surface = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF2E2A26);
  static const Color textSecondary = Color(0xFF7A736A);

  // Palette accents (member/category/status use)
  static const Color mint = Color(0xFF7FC8B8);
  static const Color coral = Color(0xFFF3927A);
  static const Color skyBlue = Color(0xFF8FB8DE);
  static const Color softYellow = Color(0xFFF3D07A);
  static const Color lavender = Color(0xFFB6A6D9);

  static const Color border = Color(0xFFEAE3D9);
  static const Color danger = Color(0xFFD9695B);
  static const Color success = Color(0xFF6FAE8C);

  /// Rotating palette for assigning a consistent color per household member.
  static const List<Color> memberPalette = [
    mint,
    coral,
    skyBlue,
    softYellow,
    lavender,
  ];

  static Color memberColor(int index) =>
      memberPalette[index % memberPalette.length];
}
