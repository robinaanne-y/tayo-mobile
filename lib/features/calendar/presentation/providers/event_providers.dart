import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(apiClientProvider));
});

/// Events visible to the current member for the whole month containing
/// [month] (any day works — only year/month are used). Powers the Calendar
/// screen's month view; re-fetches when the active household or the viewed
/// month changes.
final currentHouseholdEventsForMonthProvider =
    FutureProvider.family<List<Event>, DateTime>((ref, month) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1).subtract(const Duration(seconds: 1));

  final events = await ref
      .read(eventRepositoryProvider)
      .list(householdId: household.id, from: start, to: end);
  events.sort((a, b) => a.startAt.compareTo(b.startAt));
  return events;
});

/// Today's events for the current household — powers Home's "Today's
/// Schedule" section.
final currentHouseholdTodaysEventsProvider = FutureProvider<List<Event>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

  final events = await ref
      .read(eventRepositoryProvider)
      .list(householdId: household.id, from: start, to: end);
  events.sort((a, b) => a.startAt.compareTo(b.startAt));
  return events;
});
