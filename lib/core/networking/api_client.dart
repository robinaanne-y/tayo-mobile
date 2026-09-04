import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio that injects the Sanctum bearer token on every
/// request and normalizes failures into [ApiException].
class ApiClient {
  ApiClient({SecureTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? SecureTokenStorage(),
        _dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  /// Invoked whenever the API responds 401, so the app can clear session
  /// state centrally instead of every call site handling it.
  void Function()? onUnauthorized;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _request(() => _dio.get(path, queryParameters: queryParameters));

  Future<Response<dynamic>> post(String path, {Object? data}) =>
      _request(() => _dio.post(path, data: data));

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _request(() => _dio.patch(path, data: data));

  Future<Response<dynamic>> delete(String path) =>
      _request(() => _dio.delete(path));

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  ApiException _mapException(DioException e) {
    final response = e.response;
    if (response != null) {
      final data = response.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Something went wrong. Please try again.';

      Map<String, List<String>>? errors;
      if (data is Map && data['errors'] is Map) {
        errors = (data['errors'] as Map).map(
          (key, value) => MapEntry(
            key as String,
            (value as List).map((v) => v.toString()).toList(),
          ),
        );
      }

      return ApiException(
        message: message,
        statusCode: response.statusCode,
        errors: errors,
      );
    }

    return ApiException(
      message: 'Unable to reach the server. Check your connection.',
    );
  }
}
