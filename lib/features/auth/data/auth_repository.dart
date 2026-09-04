import '../../../core/networking/api_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _apiClient.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });

    return _persistAndReturnUser(response.data as Map<String, dynamic>);
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    return _persistAndReturnUser(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } finally {
      await _tokenStorage.clearToken();
    }
  }

  Future<AppUser> me() async {
    final response = await _apiClient.get('/auth/me');
    return AppUser.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<AppUser> _persistAndReturnUser(Map<String, dynamic> data) async {
    await _tokenStorage.saveToken(data['token'] as String);
    return AppUser.fromJson(data['data'] as Map<String, dynamic>);
  }
}
