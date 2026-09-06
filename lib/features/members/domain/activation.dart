class ActivationLink {
  const ActivationLink({required this.token, required this.link, this.expiresAt});

  final String token;
  final String link;
  final DateTime? expiresAt;

  factory ActivationLink.fromJson(Map<String, dynamic> json) {
    return ActivationLink(
      token: json['token'] as String,
      link: json['link'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }
}

class ActivationPreview {
  const ActivationPreview({
    required this.memberName,
    required this.householdName,
    required this.isValid,
  });

  final String memberName;
  final String? householdName;
  final bool isValid;

  factory ActivationPreview.fromJson(Map<String, dynamic> json) {
    return ActivationPreview(
      memberName: json['member_name'] as String,
      householdName: json['household_name'] as String?,
      isValid: json['valid'] as bool? ?? false,
    );
  }
}
