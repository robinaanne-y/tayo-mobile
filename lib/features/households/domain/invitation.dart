import '../../members/domain/member.dart';

class Invitation {
  const Invitation({
    required this.token,
    required this.link,
    required this.role,
    this.expiresAt,
  });

  final String token;
  final String link;
  final HouseholdRole role;
  final DateTime? expiresAt;

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      token: json['token'] as String,
      link: json['link'] as String,
      role: HouseholdRole.fromValue(json['role'] as String?) ?? HouseholdRole.adult,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }
}

class InvitationPreview {
  const InvitationPreview({
    required this.householdName,
    required this.role,
    required this.isValid,
  });

  final String householdName;
  final HouseholdRole role;
  final bool isValid;

  factory InvitationPreview.fromJson(Map<String, dynamic> json) {
    return InvitationPreview(
      householdName: json['household_name'] as String,
      role: HouseholdRole.fromValue(json['role'] as String?) ?? HouseholdRole.adult,
      isValid: json['valid'] as bool? ?? false,
    );
  }
}
