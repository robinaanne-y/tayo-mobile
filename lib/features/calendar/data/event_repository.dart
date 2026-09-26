import '../../../core/networking/api_client.dart';
import '../domain/event.dart';

class EventRepository {
  EventRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Event>> list({
    required int householdId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _apiClient.get(
      '/households/$householdId/events',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Event> create({
    required int householdId,
    required String title,
    String? description,
    required DateTime startAt,
    required DateTime endAt,
    required EventVisibility visibility,
    List<int> participantMemberIds = const [],
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/events',
      data: {
        'title': title,
        'description': description,
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
        'visibility': visibility.value,
        'participant_member_ids': participantMemberIds,
      },
    );
    return Event.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<Event> update({
    required int householdId,
    required int eventId,
    required String title,
    String? description,
    required DateTime startAt,
    required DateTime endAt,
    required EventVisibility visibility,
    List<int> participantMemberIds = const [],
  }) async {
    final response = await _apiClient.put(
      '/households/$householdId/events/$eventId',
      data: {
        'title': title,
        'description': description,
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
        'visibility': visibility.value,
        'participant_member_ids': participantMemberIds,
      },
    );
    return Event.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> delete({required int householdId, required int eventId}) async {
    await _apiClient.delete('/households/$householdId/events/$eventId');
  }
}
