import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Custom exceptions for authentication operations
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, [this.statusCode]);

  @override
  String toString() => 'AuthException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class NetworkException extends AuthException {
  NetworkException(super.message);
}

class InvalidTokenException extends AuthException {
  InvalidTokenException() : super('Invalid or missing authentication token');
}

/// Service for handling authentication and API requests
class AuthService {
  static const _jwtStorageKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();
  static const _requestTimeout = Duration(seconds: 30);

  static String get _apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    if (!kIsWeb && Platform.isAndroid) {
      // Android emulator maps host loopback to 10.0.2.2
      if (raw.contains('127.0.0.1')) {
        return raw.replaceAll('127.0.0.1', '10.0.2.2');
      }
      if (raw.contains('localhost')) {
        return raw.replaceAll('localhost', '10.0.2.2');
      }
    }
    return raw;
  }

  static String get _apiPathPrefix {
    final raw = (dotenv.env['API_PATH_PREFIX'] ?? '').trim();
    if (raw.isEmpty) return '';
    final withLead = raw.startsWith('/') ? raw : '/$raw';
    return withLead.endsWith('/')
        ? withLead.substring(0, withLead.length - 1)
        : withLead;
  }

  /// Logs a message if in debug mode
  static void _log(String message, {bool isError = false}) {
    if (kDebugMode) {
      if (isError) {
        developer.log(message, name: 'AuthService', error: message);
      } else {
        developer.log(message, name: 'AuthService');
      }
    }
  }

  /// Helper to make HTTP requests with timeout and error handling
  static Future<http.Response> _makeRequest({
    required Future<http.Response> Function() request,
    required String operation,
  }) async {
    try {
      _log('$operation: Starting request');
      final response = await request().timeout(_requestTimeout);
      _log('$operation: Response status ${response.statusCode}');
      return response;
    } on http.ClientException catch (e) {
      _log('$operation: Network error - $e', isError: true);
      throw NetworkException('Network error during $operation: ${e.message}');
    } catch (e) {
      _log('$operation: Unexpected error - $e', isError: true);
      throw AuthException('Failed to $operation: $e');
    }
  }

  /// Signs out the current user
  static Future<void> signOut() async {
    _log('Signing out user');
    await _storage.delete(key: _jwtStorageKey);
    try {
      await _googleSignIn().signOut();
    } catch (e) {
      _log('Error signing out from Google: $e', isError: true);
    }
  }

  /// Retrieves the stored JWT token
  static Future<String?> getJwt() => _storage.read(key: _jwtStorageKey);

  /// Saves JWT token to secure storage
  static Future<void> _saveJwt(String token) =>
      _storage.write(key: _jwtStorageKey, value: token);

  /// Signs in a user with Google OAuth
  /// Returns true if successful, false otherwise
  static Future<bool> signInWithGoogle() async {
    try {
      _log('Starting Google sign in');
      final googleSignIn = _googleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        _log('Google sign in cancelled by user');
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _log('Failed to get Google ID token', isError: true);
        return false;
      }

      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        ),
        operation: 'Google sign in',
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final token = body['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _saveJwt(token);
          _log('Google sign in successful');
          return true;
        }
        _log('Invalid token received from server', isError: true);
      } else {
        _log('Google sign in failed with status ${resp.statusCode}', isError: true);
      }
      return false;
    } catch (e) {
      _log('Google sign in error: $e', isError: true);
      return false;
    }
  }

  static GoogleSignIn _googleSignIn() {
    // Google Sign-In on Android requires the Web client ID as serverClientId
    // to obtain an ID token. Prefer the web/server client ID from env.
    final serverClientId =
        dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ??
        dotenv.env['GOOGLE_WEB_CLIENT_ID'] ??
        dotenv.env['GOOGLE_SERVER_CLIENT_ID_ANDROID'];

    if (!kIsWeb &&
        Platform.isAndroid &&
        serverClientId != null &&
        serverClientId.isNotEmpty) {
      return GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: serverClientId,
      );
    }
    return GoogleSignIn(scopes: const ['email', 'profile']);
  }

  /// Signs in a user with Apple Sign In
  /// Returns true if successful, false otherwise
  static Future<bool> signInWithApple() async {
    try {
      _log('Starting Apple sign in');
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        _log('Apple sign in not available on this device');
        return false;
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        _log('Failed to get Apple identity token', isError: true);
        return false;
      }

      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/auth/apple'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'identityToken': identityToken}),
        ),
        operation: 'Apple sign in',
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final token = body['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _saveJwt(token);
          _log('Apple sign in successful');
          return true;
        }
        _log('Invalid token received from server', isError: true);
      } else {
        _log('Apple sign in failed with status ${resp.statusCode}', isError: true);
      }
      return false;
    } catch (e) {
      _log('Apple sign in error: $e', isError: true);
      return false;
    }
  }

  /// Responds to an event with the given response and optional role
  /// Throws [InvalidTokenException] if not authenticated
  static Future<bool> respondToEvent({
    required String eventId,
    required String response,
    String? role,
  }) async {
    if (eventId.isEmpty) {
      throw ArgumentError('eventId cannot be empty');
    }
    if (response.isEmpty) {
      throw ArgumentError('response cannot be empty');
    }

    final token = await getJwt();
    if (token == null) throw InvalidTokenException();

    try {
      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/respond'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'response': response, if (role != null) 'role': role}),
        ),
        operation: 'Respond to event',
      );
      return resp.statusCode == 200;
    } catch (e) {
      _log('Failed to respond to event: $e', isError: true);
      return false;
    }
  }

  /// Gets the current user's attendance status for an event
  /// Returns null if not authenticated or request fails
  static Future<Map<String, dynamic>?> getMyAttendanceStatus({
    required String eventId,
  }) async {
    if (eventId.isEmpty) {
      throw ArgumentError('eventId cannot be empty');
    }

    final token = await getJwt();
    if (token == null) return null;

    try {
      final resp = await _makeRequest(
        request: () => http.get(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/attendance/me'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        operation: 'Get attendance status',
      );
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _log('Failed to get attendance status: $e', isError: true);
      return null;
    }
  }

  /// Clocks in the user for an event
  /// Returns the response data or null if not authenticated or request fails
  static Future<Map<String, dynamic>?> clockIn({
    required String eventId,
    String? role,
  }) async {
    if (eventId.isEmpty) {
      throw ArgumentError('eventId cannot be empty');
    }

    final token = await getJwt();
    if (token == null) return null;

    try {
      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/clock-in'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({if (role != null) 'role': role}),
        ),
        operation: 'Clock in',
      );
      if (resp.statusCode == 200 ||
          resp.statusCode == 201 ||
          resp.statusCode == 409) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _log('Failed to clock in: $e', isError: true);
      return null;
    }
  }

  /// Clocks out the user from an event
  /// Returns the response data or null if not authenticated or request fails
  static Future<Map<String, dynamic>?> clockOut({
    required String eventId,
  }) async {
    if (eventId.isEmpty) {
      throw ArgumentError('eventId cannot be empty');
    }

    final token = await getJwt();
    if (token == null) return null;

    try {
      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/clock-out'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        operation: 'Clock out',
      );
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _log('Failed to clock out: $e', isError: true);
      return null;
    }
  }

  /// Gets the current user's availability slots
  /// Returns an empty list if not authenticated or request fails
  static Future<List<Map<String, dynamic>>> getAvailability() async {
    final token = await getJwt();
    if (token == null) return [];

    try {
      final resp = await _makeRequest(
        request: () => http.get(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/availability'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        operation: 'Get availability',
      );
      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _log('Failed to get availability: $e', isError: true);
    }
    return [];
  }

  /// Sets or updates user availability for a specific time slot
  /// Returns true if successful, false otherwise
  static Future<bool> setAvailability({
    required String date,
    required String startTime,
    required String endTime,
    required String status,
  }) async {
    if (date.isEmpty) {
      throw ArgumentError('date cannot be empty');
    }
    if (startTime.isEmpty) {
      throw ArgumentError('startTime cannot be empty');
    }
    if (endTime.isEmpty) {
      throw ArgumentError('endTime cannot be empty');
    }
    if (status.isEmpty) {
      throw ArgumentError('status cannot be empty');
    }

    final token = await getJwt();
    if (token == null) return false;

    try {
      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/availability'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'date': date,
            'startTime': startTime,
            'endTime': endTime,
            'status': status,
          }),
        ),
        operation: 'Set availability',
      );
      return resp.statusCode == 200;
    } catch (e) {
      _log('Failed to set availability: $e', isError: true);
      return false;
    }
  }

  /// Deletes an availability slot by ID
  /// Returns true if successful, false otherwise
  static Future<bool> deleteAvailability({required String id}) async {
    if (id.isEmpty) {
      throw ArgumentError('id cannot be empty');
    }

    final token = await getJwt();
    if (token == null) return false;

    try {
      final resp = await _makeRequest(
        request: () => http.delete(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/availability/$id'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        operation: 'Delete availability',
      );
      return resp.statusCode == 200;
    } catch (e) {
      _log('Failed to delete availability: $e', isError: true);
      return false;
    }
  }
}
