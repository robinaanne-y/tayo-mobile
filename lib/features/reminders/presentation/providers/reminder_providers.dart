import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/reminder_repository.dart';
import '../../domain/notification_preference.dart';
import '../../domain/reminder.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(apiClientProvider));
});

/// Reminders for the current household, filtered server-side to the
/// categories this viewer hasn't disabled. Absence of any reminder is the
/// normal state — there's no "all caught up" card, unlike Tasks/Trips.
final currentHouseholdRemindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(reminderRepositoryProvider).list(householdId: household.id);
});

final notificationPreferencesProvider = FutureProvider<List<NotificationPreference>>((ref) async {
  return ref.read(reminderRepositoryProvider).getPreferences();
});
