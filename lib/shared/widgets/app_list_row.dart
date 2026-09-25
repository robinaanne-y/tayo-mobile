import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Shared "list row" anatomy — leading avatar/icon, title, optional
/// subtitle, optional trailing element — used wherever the app shows a
/// person, household, or similar entity in a list. Deliberately has no
/// background/elevation of its own: wrap it in [AppCard] for a card-style
/// row, or in a custom container for anything else (e.g. a row that needs
/// a background different from the surrounding surface, like a selectable
/// row inside a bottom sheet).
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: AppSpacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                subtitle!,
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.space8),
          trailing!,
        ],
      ],
    );
  }
}
