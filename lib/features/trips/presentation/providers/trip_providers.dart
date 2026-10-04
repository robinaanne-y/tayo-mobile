import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(apiClientProvider));
});

/// Every trip in the current household.
final currentHouseholdTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(tripRepositoryProvider).list(householdId: household.id);
});

/// The nearest trip that hasn't happened (or finished) yet, soonest first —
/// what Home's Upcoming Trip section shows. Derived from the full list
/// rather than a separate fetch, same pattern as
/// currentHouseholdTodaysTasksProvider.
final currentHouseholdUpcomingTripProvider = FutureProvider<Trip?>((ref) async {
  final trips = await ref.watch(currentHouseholdTripsProvider.future);
  final upcoming = trips.where((t) => t.isUpcoming).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  return upcoming.isEmpty ? null : upcoming.first;
});

/// Trips that have already happened (or finished) — the Past Trips
/// gallery, newest first.
final currentHouseholdPastTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final trips = await ref.watch(currentHouseholdTripsProvider.future);
  final past = trips.where((t) => t.isPast).toList()
    ..sort((a, b) => b.startAt.compareTo(a.startAt));
  return past;
});

/// A single trip's full detail (participants, itinerary, memories) — a
/// fresh fetch rather than reading from the list providers above, so it
/// reflects the server's current days_until/status even on stale cached
/// list data.
final tripDetailProvider = FutureProvider.family<Trip?, int>((ref, tripId) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return null;

  return ref.read(tripRepositoryProvider).show(householdId: household.id, tripId: tripId);
});
