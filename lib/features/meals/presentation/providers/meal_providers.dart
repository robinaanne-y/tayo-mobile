import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/meal_plan_repository.dart';
import '../../data/meal_request_repository.dart';
import '../../domain/meal_plan_item.dart';
import '../../domain/meal_request.dart';

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return MealPlanRepository(ref.watch(apiClientProvider));
});

final mealRequestRepositoryProvider = Provider<MealRequestRepository>((ref) {
  return MealRequestRepository(ref.watch(apiClientProvider));
});

/// Meal plan items within an arbitrary [start, end] range — powers the
/// Meals screen's week strip/day view, same family-provider-by-range
/// pattern as `currentHouseholdEventsInRangeProvider`.
final currentHouseholdMealPlanProvider =
    FutureProvider.family<List<MealPlanItem>, ({DateTime start, DateTime end})>((ref, range) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref
      .read(mealPlanRepositoryProvider)
      .list(householdId: household.id, from: range.start, to: range.end);
});

/// Today's planned meals — powers Home's "Today's Meals" section.
final currentHouseholdTodaysMealsProvider = FutureProvider<List<MealPlanItem>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return ref.read(mealPlanRepositoryProvider).list(householdId: household.id, from: today, to: today);
});

/// Every meal request in the current household, newest first — powers the
/// Meals screen's "Requests" section and feeds into Home's unified
/// notifications (alongside permission requests).
final currentHouseholdMealRequestsProvider = FutureProvider<List<MealRequest>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(mealRequestRepositoryProvider).list(householdId: household.id);
});
