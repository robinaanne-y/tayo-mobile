import '../../requests/domain/permission_request.dart' show RequestStatus;
import 'meal_plan_item.dart';

class MealRequest {
  const MealRequest({
    required this.id,
    required this.householdId,
    required this.requesterMemberId,
    required this.requesterName,
    required this.requestedDate,
    required this.requestedSlot,
    required this.title,
    required this.status,
    required this.respondedByName,
    required this.respondedAt,
    required this.responseNote,
    required this.mealPlanItemId,
    required this.needsRequesterAttention,
  });

  final int id;
  final int householdId;
  final int requesterMemberId;
  final String requesterName;
  final DateTime requestedDate;
  final MealSlot requestedSlot;
  final String title;
  final RequestStatus status;
  final String? respondedByName;
  final DateTime? respondedAt;
  final String? responseNote;
  final int? mealPlanItemId;
  final bool needsRequesterAttention;

  factory MealRequest.fromJson(Map<String, dynamic> json) {
    return MealRequest(
      id: json['id'] as int,
      householdId: json['household_id'] as int,
      requesterMemberId: json['requester_member_id'] as int,
      requesterName: json['requester_name'] as String? ?? '',
      requestedDate: DateTime.parse(json['requested_date'] as String),
      requestedSlot: MealSlot.fromValue(json['requested_slot'] as String),
      title: json['title'] as String,
      status: RequestStatus.fromValue(json['status'] as String),
      respondedByName: json['responded_by_name'] as String?,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String).toLocal()
          : null,
      responseNote: json['response_note'] as String?,
      mealPlanItemId: json['meal_plan_item_id'] as int?,
      needsRequesterAttention: json['needs_requester_attention'] as bool? ?? false,
    );
  }
}
