/// A normalized error surfaced from the API, translated from either a
/// Laravel validation (422) response or a generic HTTP/network failure.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  String? firstErrorFor(String field) => errors?[field]?.first;

  bool get isValidationError => statusCode == 422;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
