import '../../../core/networking/api_client.dart';
import '../domain/activation.dart';

/// Handles the public, unauthenticated side of member activation — previewing
/// a token before the claimant has an account. Claiming itself lives on
/// [AuthRepository] since it logs the new user in, mirroring register/login.
class ActivationRepository {
  ActivationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ActivationPreview> preview(String token) async {
    final response = await _apiClient.get('/activation/$token');
    return ActivationPreview.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }
}
