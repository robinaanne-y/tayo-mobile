import '../../../core/networking/api_client.dart';
import '../domain/member.dart';

class MemberRepository {
  MemberRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Member>> forHousehold(int householdId) async {
    final response = await _apiClient.get('/households/$householdId/members');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((m) => Member.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<Member> create({
    required int householdId,
    required String name,
    required HouseholdRole role,
    DateTime? birthDate,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/members',
      data: {
        'name': name,
        'role': role.name,
        if (birthDate != null)
          'birth_date':
              '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
      },
    );

    return Member.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }
}
