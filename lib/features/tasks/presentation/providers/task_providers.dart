import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/task_repository.dart';
import '../../domain/task_item.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(apiClientProvider));
});

/// Every task in the current household — the Tasks screen splits/filters
/// this client-side (by assignee, status) rather than one fetch per filter,
/// matching how Groceries handles its own small, single-household list.
final currentHouseholdTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(taskRepositoryProvider).list(householdId: household.id);
});

/// Due today or overdue, and not yet completed — what Home's Tasks section
/// shows.
final currentHouseholdTodaysTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  final tasks = await ref.watch(currentHouseholdTasksProvider.future);
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  return tasks.where((task) {
    if (task.isCompleted || task.dueAt == null) return false;
    final dueDate = DateTime(task.dueAt!.year, task.dueAt!.month, task.dueAt!.day);
    return !dueDate.isAfter(todayDate);
  }).toList();
});

/// A trip's checklist/tasks -- just the current household's tasks filtered
/// by trip_id server-side, not a separate concept (see TripDetailScreen).
final tripTasksProvider = FutureProvider.family<List<TaskItem>, int>((ref, tripId) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(taskRepositoryProvider).list(householdId: household.id, tripId: tripId);
});
