class TripMemory {
  const TripMemory({
    required this.id,
    required this.tripId,
    required this.memberId,
    required this.memberName,
    required this.memberAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int tripId;
  final int memberId;
  final String? memberName;
  final String? memberAvatarUrl;
  final String content;
  final DateTime createdAt;

  factory TripMemory.fromJson(Map<String, dynamic> json) {
    return TripMemory(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      memberId: json['member_id'] as int,
      memberName: json['member_name'] as String?,
      memberAvatarUrl: json['member_avatar_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
