import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_token_storage.dart';
import 'api_client.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStorage: ref.watch(secureTokenStorageProvider));
});
