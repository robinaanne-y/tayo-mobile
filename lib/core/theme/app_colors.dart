import 'package:flutter/material.dart';

/// Identity/status colors that stay fixed across Light and Dark — a
/// person's (or status's) color shouldn't shift when the theme does.
/// Everything that *does* change between themes lives in
/// `AppColorTokens` (`app_color_tokens.dart`) instead, read via
/// `context.colors`.
class AppColors {
  AppColors._();

  static const Color lavender = Color(0xFF9B8EC4);
  static const Color skyBlue = Color(0xFF5B9BD5);
  static const Color coral = Color(0xFFE8897A);
  static const Color mint = Color(0xFF4FBDAD);
  static const Color softYellow = Color(0xFFF5C066);

  static const Color statusHome = mint;
  static const Color statusWork = skyBlue;
  static const Color statusSchool = coral;

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
