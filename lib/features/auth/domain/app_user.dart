import '../../households/domain/household.dart';
import '../../members/domain/member.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.member,
    this.households = const [],
  });

  final int id;
  final String name;
  final String email;
  final Member? member;
  final List<Household> households;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      member: json['member'] != null
          ? Member.fromJson(json['member'] as Map<String, dynamic>)
          : null,
      households: json['households'] != null
          ? (json['households'] as List)
              .map((h) => Household.fromJson(h as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }
}
