class Announcement {
  const Announcement({
    required this.id,
    required this.content,
    required this.authorMemberId,
    required this.authorName,
    required this.createdAt,
  });

  final int id;
  final String content;
  final int authorMemberId;
  final String authorName;
  final DateTime createdAt;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as int,
      content: json['content'] as String,
      authorMemberId: json['author_member_id'] as int,
      authorName: json['author_name'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
