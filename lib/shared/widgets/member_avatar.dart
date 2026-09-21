import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';

/// Circular avatar showing a member's photo, or their initials on a tinted
/// background (colored consistently via [AppColors.memberColor]) when they
/// don't have one.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.colorIndex,
    this.avatarUrl,
    this.size = 44,
  });

  final String name;
  final int colorIndex;
  final String? avatarUrl;
  final double size;

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0]).join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.memberColor(colorIndex);
    final url = avatarUrl;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
      ),
      child: url == null
          ? Text(
              _initials,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32,
              ),
            )
          : Image.network(
              '${Env.mediaBaseUrl}$url',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Text(
                _initials,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.32,
                ),
              ),
            ),
    );
  }
}
