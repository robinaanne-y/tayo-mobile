import '../../calendar/domain/event.dart';
import 'trip_itinerary_item.dart';
import 'trip_memory.dart';

enum TripStatus {
  planning('planning'),
  confirmed('confirmed'),
  completed('completed'),
  cancelled('cancelled');

  const TripStatus(this.value);

  final String value;

  static TripStatus fromValue(String value) {
    return TripStatus.values.firstWhere((v) => v.value == value);
  }
}

class Trip {
  const Trip({
    required this.id,
    required this.householdId,
    required this.title,
    required this.destination,
    required this.startAt,
    required this.endAt,
    required this.notes,
    required this.status,
    required this.thumbnailUrl,
    required this.daysUntil,
    required this.participants,
    required this.itineraryItems,
    required this.memories,
    required this.createdByMemberId,
    required this.createdByName,
    required this.createdAt,
  });

  final int id;
  final int householdId;
  final String title;
  final String? destination;
  final DateTime startAt;
  final DateTime? endAt;
  final String? notes;
  final TripStatus status;
  final String? thumbnailUrl;
  final int? daysUntil;
  final List<EventParticipant> participants;
  final List<TripItineraryItem> itineraryItems;
  final List<TripMemory> memories;
  final int createdByMemberId;
  final String? createdByName;
  final DateTime createdAt;

  bool get isPast {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final endDate = endAt ?? startAt;
    return endDate.isBefore(todayDate);
  }

  bool get isUpcoming =>
      !isPast && status != TripStatus.completed && status != TripStatus.cancelled;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as int,
      householdId: json['household_id'] as int,
      title: json['title'] as String,
      destination: json['destination'] as String?,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: json['end_at'] != null ? DateTime.parse(json['end_at'] as String) : null,
      notes: json['notes'] as String?,
      status: TripStatus.fromValue(json['status'] as String),
      thumbnailUrl: json['thumbnail_url'] as String?,
      daysUntil: json['days_until'] as int?,
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((p) => EventParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
      itineraryItems: (json['itinerary_items'] as List<dynamic>? ?? [])
          .map((i) => TripItineraryItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      memories: (json['memories'] as List<dynamic>? ?? [])
          .map((m) => TripMemory.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdByMemberId: json['created_by_member_id'] as int,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
