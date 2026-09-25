import 'package:flutter/material.dart';

/// Theme-dependent semantic colors — everything that must change between
/// Light and Dark (backgrounds, text, borders, brand colors). Registered on
/// [ThemeData.extensions] by `AppTheme`; read via the [AppColorsX] context
/// getter rather than a static constant, since these genuinely differ per
/// theme and so can't be `const`.
///
/// Member-identity hues and status colors are deliberately NOT here — see
/// `AppColors` in `app_colors.dart` for those, which stay fixed across
/// themes by design.
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.primaryForeground,
    required this.accent,
    required this.coral,
    required this.warning,
    required this.error,
    required this.success,
    required this.info,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.icon,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color primaryForeground;
  final Color accent;
  final Color coral;
  final Color warning;
  final Color error;
  final Color success;
  final Color info;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color icon;

  static const light = AppColorTokens(
    background: Color(0xFFF7FAF9),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF4F2),
    primary: Color(0xFF127D6B),
    primaryStrong: Color(0xFF0E6658),
    primarySoft: Color(0xFFE2F4EF),
    primaryForeground: Color(0xFFFFFFFF),
    accent: Color(0xFFF4B23D),
    coral: Color(0xFFE8897A),
    warning: Color(0xFFF5A623),
    error: Color(0xFFE65353),
    success: Color(0xFF36A985),
    info: Color(0xFF3D95E8),
    border: Color(0xFFE1EAE7),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF64748B),
    textDisabled: Color(0xFF9AA7B2),
    icon: Color(0xFF49616A),
  );

  static const dark = AppColorTokens(
    background: Color(0xFF0B111B),
    surface: Color(0xFF141E2B),
    surfaceAlt: Color(0xFF1B2A3A),
    primary: Color(0xFF42CDB6),
    primaryStrong: Color(0xFF2DB59F),
    primarySoft: Color(0xFF173B3A),
    primaryForeground: Color(0xFF071411),
    accent: Color(0xFFF4B23D),
    coral: Color(0xFFFF7A70),
    warning: Color(0xFFFFBE55),
    error: Color(0xFFFF6B6B),
    success: Color(0xFF5BD0A8),
    info: Color(0xFF62B5FF),
    border: Color(0xFF2B3A4A),
    textPrimary: Color(0xFFF5F7FB),
    textSecondary: Color(0xFFAAB8C8),
    textDisabled: Color(0xFF718096),
    icon: Color(0xFFB5C5D4),
  );

  @override
  AppColorTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? primaryStrong,
    Color? primarySoft,
    Color? primaryForeground,
    Color? accent,
    Color? coral,
    Color? warning,
    Color? error,
    Color? success,
    Color? info,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? icon,
  }) {
    return AppColorTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      accent: accent ?? this.accent,
      coral: coral ?? this.coral,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      success: success ?? this.success,
      info: info ?? this.info,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      icon: icon ?? this.icon,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryForeground: Color.lerp(primaryForeground, other.primaryForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
    );
  }
}

/// Ergonomic access: `context.colors.primary` instead of
/// `Theme.of(context).extension<AppColorTokens>()!.primary`.
extension AppColorsX on BuildContext {
  AppColorTokens get colors => Theme.of(this).extension<AppColorTokens>()!;
}
