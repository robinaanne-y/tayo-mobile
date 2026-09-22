class FamilyNote {
  const FamilyNote({
    required this.id,
    required this.content,
    required this.authorMemberId,
    required this.authorName,
    required this.expiresAt,
  });

  final int id;
  final String content;
  final int authorMemberId;
  final String authorName;
  final DateTime expiresAt;

  factory FamilyNote.fromJson(Map<String, dynamic> json) {
    return FamilyNote(
      id: json['id'] as int,
      content: json['content'] as String,
      authorMemberId: json['author_member_id'] as int,
      authorName: json['author_name'] as String? ?? '',
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
