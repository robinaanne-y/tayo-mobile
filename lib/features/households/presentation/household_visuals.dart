import 'package:flutter/material.dart';

import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/app_colors.dart';

/// Shared palette for a household's accent color and icon — offered when
/// creating a household and again when editing it later in Household
/// settings, so both flows stay visually consistent. A function (not a
/// `const` list) because `primary`/`accent` are theme-dependent.
List<Color> kHouseholdColors(BuildContext context) => [
      context.colors.primary,
      AppColors.skyBlue,
      context.colors.accent,
      AppColors.lavender,
      AppColors.softYellow,
    ];

const kHouseholdEmojis = ['🏡', '🏠', '🌿', '⭐', '🐾', '🍀', '🌞'];

String householdColorToHex(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2).toUpperCase()}';
}

Color householdColorFromHex(BuildContext context, String? hex) {
  if (hex == null) return kHouseholdColors(context).first;
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}
