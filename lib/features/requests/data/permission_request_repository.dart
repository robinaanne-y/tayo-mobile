import '../../../core/networking/api_client.dart';
import '../domain/permission_request.dart';

class PermissionRequestRepository {
  PermissionRequestRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PermissionRequest>> list({
    required int householdId,
    RequestStatus? status,
  }) async {
    final response = await _apiClient.get(
      '/households/$householdId/requests',
      queryParameters: status != null ? {'status': status.value} : null,
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((r) => PermissionRequest.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<PermissionRequest> create({
    required int householdId,
    required String title,
    String? type,
    String? description,
    DateTime? requestedStartAt,
    DateTime? requestedEndAt,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/requests',
      data: {
        'title': title,
        'type': type,
        'description': description,
        if (requestedStartAt != null)
          'requested_start_at': requestedStartAt.toUtc().toIso8601String(),
        if (requestedEndAt != null) 'requested_end_at': requestedEndAt.toUtc().toIso8601String(),
      },
    );
    return PermissionRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<PermissionRequest> update({
    required int householdId,
    required int requestId,
    required String title,
    String? type,
    String? description,
    DateTime? requestedStartAt,
    DateTime? requestedEndAt,
  }) async {
    final response = await _apiClient.put(
      '/households/$householdId/requests/$requestId',
      data: {
        'title': title,
        'type': type,
        'description': description,
        if (requestedStartAt != null)
          'requested_start_at': requestedStartAt.toUtc().toIso8601String(),
        if (requestedEndAt != null) 'requested_end_at': requestedEndAt.toUtc().toIso8601String(),
      },
    );
    return PermissionRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<PermissionRequest> approve({
    required int householdId,
    required int requestId,
    String? responseNote,
    List<String> conditions = const [],
    bool createEvent = false,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/requests/$requestId/approve',
      data: {
        'response_note': responseNote,
        'conditions': conditions,
        'create_event': createEvent,
      },
    );
    return PermissionRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<PermissionRequest> decline({
    required int householdId,
    required int requestId,
    String? responseNote,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/requests/$requestId/decline',
      data: {'response_note': responseNote},
    );
    return PermissionRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<PermissionRequest> cancel({
    required int householdId,
    required int requestId,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/requests/$requestId/cancel',
    );
    return PermissionRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<PermissionRequest> acknowledge({
    required int householdId,
    required int requestId,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/requests/$requestId/acknowledge',
    );
    return PermissionRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<PermissionRequest> addCondition({
    required int householdId,
    required int requestId,
    required String description,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/requests/$requestId/conditions',
      data: {'description': description},
    );
    return PermissionRequest.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }
}
