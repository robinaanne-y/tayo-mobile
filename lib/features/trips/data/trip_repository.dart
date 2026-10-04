import 'package:dio/dio.dart';

import '../../../core/networking/api_client.dart';
import '../domain/trip.dart';
import '../domain/trip_itinerary_item.dart';
import '../domain/trip_memory.dart';

class TripRepository {
  TripRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Trip>> list({required int householdId}) async {
    final response = await _apiClient.get('/households/$householdId/trips');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Trip> show({required int householdId, required int tripId}) async {
    final response = await _apiClient.get('/households/$householdId/trips/$tripId');
    return Trip.fromJson((response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<Trip> create({
    required int householdId,
    required String title,
    String? destination,
    required DateTime startAt,
    DateTime? endAt,
    String? notes,
    List<int> participantMemberIds = const [],
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/trips',
      data: {
        'title': title,
        'destination': destination,
        'start_at': _dateOnly(startAt),
        'end_at': endAt != null ? _dateOnly(endAt) : null,
        'notes': notes,
        'participant_member_ids': participantMemberIds,
      },
    );
    return Trip.fromJson((response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<Trip> update({
    required int householdId,
    required int tripId,
    required String title,
    String? destination,
    required DateTime startAt,
    DateTime? endAt,
    String? notes,
    TripStatus? status,
    List<int>? participantMemberIds,
  }) async {
    final response = await _apiClient.put(
      '/households/$householdId/trips/$tripId',
      data: {
        'title': title,
        'destination': destination,
        'start_at': _dateOnly(startAt),
        'end_at': endAt != null ? _dateOnly(endAt) : null,
        'notes': notes,
        if (status != null) 'status': status.value,
        if (participantMemberIds != null) 'participant_member_ids': participantMemberIds,
      },
    );
    return Trip.fromJson((response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<void> delete({required int householdId, required int tripId}) async {
    await _apiClient.delete('/households/$householdId/trips/$tripId');
  }

  Future<Trip> uploadThumbnail({
    required int householdId,
    required int tripId,
    required String filePath,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/trips/$tripId/thumbnail',
      data: FormData.fromMap({
        'thumbnail': await MultipartFile.fromFile(filePath),
      }),
    );
    return Trip.fromJson((response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<TripItineraryItem> addItineraryItem({
    required int householdId,
    required int tripId,
    required String title,
    String? description,
    required DateTime scheduledAt,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/trips/$tripId/itinerary',
      data: {
        'title': title,
        'description': description,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      },
    );
    return TripItineraryItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<TripItineraryItem> updateItineraryItem({
    required int householdId,
    required int tripId,
    required int itineraryItemId,
    required String title,
    String? description,
    required DateTime scheduledAt,
  }) async {
    final response = await _apiClient.put(
      '/households/$householdId/trips/$tripId/itinerary/$itineraryItemId',
      data: {
        'title': title,
        'description': description,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      },
    );
    return TripItineraryItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteItineraryItem({
    required int householdId,
    required int tripId,
    required int itineraryItemId,
  }) async {
    await _apiClient.delete('/households/$householdId/trips/$tripId/itinerary/$itineraryItemId');
  }

  Future<TripMemory> setMyMemory({
    required int householdId,
    required int tripId,
    required String content,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/trips/$tripId/memory',
      data: {'content': content},
    );
    return TripMemory.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteMemory({
    required int householdId,
    required int tripId,
    required int memoryId,
  }) async {
    await _apiClient.delete('/households/$householdId/trips/$tripId/memories/$memoryId');
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
