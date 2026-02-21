import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single field-level validation error parsed from a Zod issue object.
class FieldError {
  final String field;
  final String message;
  final String? code;

  const FieldError({
    required this.field,
    required this.message,
    this.code,
  });

  factory FieldError.fromMap(Map<String, dynamic> map) {
    final path = map['path'] as List<dynamic>?;
    return FieldError(
      field: path != null && path.isNotEmpty ? path.first.toString() : '',
      message: map['message']?.toString() ?? '',
      code: map['code']?.toString(),
    );
  }

  @override
  String toString() => 'FieldError($field: $message)';
}

/// Structured exception for API errors.
///
/// Parses the backend's JSON error responses which follow the shape:
/// ```json
/// { "message": "...", "details": [{ "path": ["field"], "message": "...", "code": "..." }] }
/// ```
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final List<FieldError> fieldErrors;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const [],
  });

  /// Parse a non-200 [http.Response] into an [ApiException].
  factory ApiException.fromResponse(http.Response response) {
    String message = 'Request failed';
    List<FieldError> fieldErrors = [];

    try {
      final body = json.decode(response.body) as Map<String, dynamic>;
      message = body['message']?.toString() ?? message;

      final details = body['details'] as List<dynamic>?;
      if (details != null) {
        fieldErrors = details
            .whereType<Map<String, dynamic>>()
            .map(FieldError.fromMap)
            .toList();
      }
    } catch (_) {
      // Body wasn't valid JSON — keep the default message
    }

    return ApiException(
      statusCode: response.statusCode,
      message: message,
      fieldErrors: fieldErrors,
    );
  }

  /// Wraps a network-level error (SocketException, TimeoutException, etc.).
  factory ApiException.network(Object error) {
    return ApiException(
      statusCode: 0,
      message: error.toString(),
    );
  }

  // ── Convenience getters ──────────────────────────────────────────────────

  bool get isValidation => statusCode == 400 && fieldErrors.isNotEmpty;
  bool get isConflict => statusCode == 409;
  bool get isNotAuthenticated => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 0;

  /// Look up the first error message for a specific field name.
  String? fieldErrorFor(String fieldName) {
    for (final e in fieldErrors) {
      if (e.field == fieldName) return e.message;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
