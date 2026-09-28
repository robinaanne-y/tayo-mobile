enum RequestStatus {
  pending('pending'),
  approved('approved'),
  declined('declined'),
  cancelled('cancelled'),
  expired('expired');

  const RequestStatus(this.value);

  final String value;

  static RequestStatus fromValue(String value) {
    return RequestStatus.values.firstWhere((v) => v.value == value);
  }
}

class RequestCondition {
  const RequestCondition({
    required this.id,
    required this.description,
    required this.createdByName,
    required this.createdAt,
  });

  final int id;
  final String description;
  final String? createdByName;
  final DateTime createdAt;

  factory RequestCondition.fromJson(Map<String, dynamic> json) {
    return RequestCondition(
      id: json['id'] as int,
      description: json['description'] as String,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class PermissionRequest {
  const PermissionRequest({
    required this.id,
    required this.householdId,
    required this.requesterMemberId,
    required this.requesterName,
    required this.type,
    required this.title,
    required this.description,
    required this.requestedStartAt,
    required this.requestedEndAt,
    required this.status,
    required this.respondedByName,
    required this.respondedAt,
    required this.responseNote,
    required this.conditions,
    required this.promotedEventId,
    required this.isOverdue,
  });

  final int id;
  final int householdId;
  final int requesterMemberId;
  final String requesterName;
  final String? type;
  final String title;
  final String? description;
  final DateTime? requestedStartAt;
  final DateTime? requestedEndAt;
  final RequestStatus status;
  final String? respondedByName;
  final DateTime? respondedAt;
  final String? responseNote;
  final List<RequestCondition> conditions;
  final int? promotedEventId;
  final bool isOverdue;

  bool get hasTimeWindow => requestedStartAt != null && requestedEndAt != null;

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      id: json['id'] as int,
      householdId: json['household_id'] as int,
      requesterMemberId: json['requester_member_id'] as int,
      requesterName: json['requester_name'] as String? ?? '',
      type: json['type'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      requestedStartAt: json['requested_start_at'] != null
          ? DateTime.parse(json['requested_start_at'] as String).toLocal()
          : null,
      requestedEndAt: json['requested_end_at'] != null
          ? DateTime.parse(json['requested_end_at'] as String).toLocal()
          : null,
      status: RequestStatus.fromValue(json['status'] as String),
      respondedByName: json['responded_by_name'] as String?,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String).toLocal()
          : null,
      responseNote: json['response_note'] as String?,
      conditions: (json['conditions'] as List<dynamic>? ?? [])
          .map((c) => RequestCondition.fromJson(c as Map<String, dynamic>))
          .toList(),
      promotedEventId: json['promoted_event_id'] as int?,
      isOverdue: json['is_overdue'] as bool? ?? false,
    );
  }
}
