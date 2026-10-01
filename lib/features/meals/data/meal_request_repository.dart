import '../../../core/networking/api_client.dart';
import '../../requests/domain/permission_request.dart' show RequestStatus;
import '../domain/meal_plan_item.dart';
import '../domain/meal_request.dart';

class MealRequestRepository {
  MealRequestRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MealRequest>> list({
    required int householdId,
    RequestStatus? status,
  }) async {
    final response = await _apiClient.get(
      '/households/$householdId/meal-requests',
      queryParameters: status != null ? {'status': status.value} : null,
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => MealRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MealRequest> create({
    required int householdId,
    required DateTime requestedDate,
    required MealSlot requestedSlot,
    required String title,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/meal-requests',
      data: {
        'requested_date': _dateString(requestedDate),
        'requested_slot': requestedSlot.value,
        'title': title,
      },
    );
    return MealRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<MealRequest> approve({
    required int householdId,
    required int requestId,
    String? responseNote,
    DateTime? date,
    MealSlot? slot,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/meal-requests/$requestId/approve',
      data: {
        'response_note': responseNote,
        if (date != null) 'date': _dateString(date),
        if (slot != null) 'slot': slot.value,
      },
    );
    return MealRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<MealRequest> decline({
    required int householdId,
    required int requestId,
    String? responseNote,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/meal-requests/$requestId/decline',
      data: {'response_note': responseNote},
    );
    return MealRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<MealRequest> cancel({required int householdId, required int requestId}) async {
    final response = await _apiClient.post('/households/$householdId/meal-requests/$requestId/cancel');
    return MealRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<MealRequest> acknowledge({required int householdId, required int requestId}) async {
    final response = await _apiClient.post('/households/$householdId/meal-requests/$requestId/acknowledge');
    return MealRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
