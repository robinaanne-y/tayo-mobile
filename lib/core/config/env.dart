/// Environment configuration for the API client.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
///
/// The default targets a Laravel dev server on the same machine. Android
/// emulators must override with 10.0.2.2 instead of 127.0.0.1/localhost.
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  /// Scheme + host (+ port) only, e.g. `http://127.0.0.1:8000` — for
  /// resolving relative media paths like a member's `avatar_url`, which
  /// the backend deliberately returns without a host baked in.
  static String get mediaBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    return uri.replace(path: '', query: '').toString();
  }
}
