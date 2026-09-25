import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(apiClientProvider));
});

/// Events visible to the current member within an arbitrary [start, end]
/// range. Powers the Calendar screen, which computes a different range per
/// view mode (a month, a week, or a single day); re-fetches when the active
/// household or the requested range changes.
final currentHouseholdEventsInRangeProvider =
    FutureProvider.family<List<Event>, ({DateTime start, DateTime end})>((ref, range) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  final events = await ref
      .read(eventRepositoryProvider)
      .list(householdId: household.id, from: range.start, to: range.end);
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
