import '../../../core/networking/api_client.dart';
import '../../members/domain/member.dart';
import '../domain/invitation.dart';

class InvitationRepository {
  InvitationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Invitation> create({
    required int householdId,
    required HouseholdRole role,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/invitations',
      data: {'role': role.name},
    );

    return Invitation.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<InvitationPreview> preview(String token) async {
    final response = await _apiClient.get('/invitations/$token');
    return InvitationPreview.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> accept(String token) async {
    await _apiClient.post('/invitations/$token/accept');
  }
}
