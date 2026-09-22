import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shared palette for a household's accent color and icon — offered when
/// creating a household and again when editing it later in Household
/// settings, so both flows stay visually consistent.
const kHouseholdColors = [
  AppColors.primary,
  AppColors.skyBlue,
  AppColors.accent,
  AppColors.lavender,
  AppColors.softYellow,
];

const kHouseholdEmojis = ['🏡', '🏠', '🌿', '⭐', '🐾', '🍀', '🌞'];

String householdColorToHex(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2).toUpperCase()}';
}

Color householdColorFromHex(String? hex) {
  if (hex == null) return kHouseholdColors.first;
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}
