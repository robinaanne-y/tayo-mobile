import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/api_exception.dart';
import '../../domain/notification_preference.dart';
import '../providers/reminder_providers.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, String category, bool enabled) async {
    try {
      await ref.read(reminderRepositoryProvider).updatePreference(category: category, enabled: enabled);
      ref.invalidate(notificationPreferencesProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: prefsAsync.when(
          data: (prefs) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Reminders',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final pref in prefs)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(kReminderCategoryLabels[pref.category] ?? pref.category),
                  value: pref.enabled,
                  onChanged: (value) => _toggle(context, ref, pref.category, value),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(error is ApiException ? error.message : 'Something went wrong.'),
          ),
        ),
      ),
    );
  }
}
