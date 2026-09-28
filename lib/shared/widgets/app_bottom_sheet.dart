import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Shows a rounded, drag-handled bottom sheet matching the app's design
/// system, with sensible padding and keyboard-avoidance baked in.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.space20,
        right: AppSpacing.space20,
        top: AppSpacing.space12,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space24,
      ),
      // showModalBottomSheet already caps this builder's result to a bounded
      // max height (the screen height, since isScrollControlled defaults to
      // true) — without a scroll view here, content taller than that (e.g.
      // a Participants picker that wraps to two rows once a household has
      // enough members) has nowhere to go but overflow past the bottom.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.space16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Builder(builder: builder),
          ],
        ),
      ),
    ),
  );
}
