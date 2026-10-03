import '../../../core/networking/api_client.dart';
import '../../calendar/domain/event.dart';
import '../domain/task_item.dart';

class TaskRepository {
  TaskRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<TaskItem>> list({
    required int householdId,
    int? assigneeMemberId,
    String? status,
    DateTime? dueBefore,
    DateTime? dueAfter,
  }) async {
    final response = await _apiClient.get(
      '/households/$householdId/tasks',
      queryParameters: {
        if (assigneeMemberId != null) 'assignee_member_id': assigneeMemberId,
        if (status != null) 'status': status,
        if (dueBefore != null) 'due_before': _dateOnly(dueBefore),
        if (dueAfter != null) 'due_after': _dateOnly(dueAfter),
      },
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaskItem> create({
    required int householdId,
    required String title,
    String? description,
    required DateTime dueAt,
    int? assignedMemberId,
    RecurrenceFrequency? recurrenceFrequency,
    int recurrenceInterval = 1,
    List<int>? recurrenceByDay,
    DateTime? recurrenceEndsAt,
    int? recurrenceOccurrenceCount,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/tasks',
      data: {
        'title': title,
        'description': description,
        'due_at': _dateOnly(dueAt),
        'assigned_member_id': assignedMemberId,
        if (recurrenceFrequency != null)
          'recurrence': {
            'frequency': recurrenceFrequency.value,
            'interval': recurrenceInterval,
            if (recurrenceByDay != null) 'by_day': recurrenceByDay,
            if (recurrenceEndsAt != null) 'ends_at': _dateOnly(recurrenceEndsAt),
            if (recurrenceOccurrenceCount != null) 'occurrence_count': recurrenceOccurrenceCount,
          },
      },
    );
    return TaskItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<TaskItem> update({
    required int householdId,
    required int taskId,
    required String title,
    String? description,
    required DateTime dueAt,
    int? assignedMemberId,
  }) async {
    final response = await _apiClient.put(
      '/households/$householdId/tasks/$taskId',
      data: {
        'title': title,
        'description': description,
        'due_at': _dateOnly(dueAt),
        'assigned_member_id': assignedMemberId,
      },
    );
    return TaskItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<TaskItem> complete({required int householdId, required int taskId}) async {
    final response = await _apiClient.post('/households/$householdId/tasks/$taskId/complete');
    return TaskItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<TaskItem> uncomplete({required int householdId, required int taskId}) async {
    final response = await _apiClient.post('/households/$householdId/tasks/$taskId/uncomplete');
    return TaskItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> delete({required int householdId, required int taskId}) async {
    await _apiClient.delete('/households/$householdId/tasks/$taskId');
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
