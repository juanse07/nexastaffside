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
  static Future<String?> getJwt() async {
    try {
      return await _storage.read(key: _jwtStorageKey);
    } catch (e) {
      _log('Error reading JWT from secure storage: $e', isError: true);
      // Clear corrupted storage and return null
      await _storage.delete(key: _jwtStorageKey);
      return null;
    }
  }

  /// Saves JWT token to secure storage
  static Future<void> _saveJwt(String token) async {
    try {
      await _storage.write(key: _jwtStorageKey, value: token);
    } catch (e) {
      _log('Error writing JWT to secure storage: $e', isError: true);
      // Try to clear and retry once
      try {
        await _storage.deleteAll();
        await _storage.write(key: _jwtStorageKey, value: token);
        _log('Successfully saved JWT after clearing storage');
      } catch (retryError) {
        _log('Failed to save JWT even after clearing storage: $retryError', isError: true);
        rethrow;
      }
    }
  }

  /// Signs in a user with Google OAuth
  /// Returns true if successful, false otherwise
  static Future<bool> signInWithGoogle({void Function(String message)? onError}) async {
    try {
      _log('Starting Google sign in');
      final googleSignIn = _googleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        _log('Google sign in cancelled by user');
        onError?.call('Sign-in cancelled');
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _log('Failed to get Google ID token', isError: true);
        onError?.call('No ID token returned by Google. Check iOS client/URL scheme');
        return false;
      }

      // Debug: Log token audience/issuer to verify configuration (masked)
      try {
        final parts = idToken.split('.');
        if (parts.length == 3) {
          final payloadStr = utf8.decode(base64Url.decode(_normalizeBase64(parts[1])));
          final payload = json.decode(payloadStr) as Map<String, dynamic>;
          final aud = (payload['aud']?.toString() ?? '').replaceAll(RegExp(r'(^.{6}|.{6}$)'), '***');
          final iss = payload['iss']?.toString();
          final azp = payload['azp']?.toString();
          _log('Google idToken aud(masked)=${aud}, iss=$iss, azp=$azp');
        }
      } catch (e) {
        _log('Failed to decode idToken payload: $e', isError: true);
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
        onError?.call('API returned invalid token payload');
      } else {
        _log('Google sign in failed with status ${resp.statusCode}', isError: true);
        final body = resp.body;
        onError?.call('API ${resp.statusCode}${body.isNotEmpty ? ': '+(body.length>120?body.substring(0,120)+'...':body) : ''}');
      }
      return false;
    } catch (e) {
      _log('Google sign in error: $e', isError: true);
      onError?.call('Exception: $e');
      return false;
    }
  }

  static String _normalizeBase64(String input) {
    final pad = input.length % 4;
    if (pad == 2) return '${input}==';
    if (pad == 3) return '${input}=';
    if (pad == 1) return '${input}===';
    return input;
  }

  static GoogleSignIn _googleSignIn() {
    // Prefer the Server (web) client ID from GCP as serverClientId on all platforms
    // so Google returns an ID token suitable for backend verification.
    final serverClientId = dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ??
        dotenv.env['GOOGLE_SERVER_CLIENT_ID_ANDROID'] ??
        dotenv.env['GOOGLE_WEB_CLIENT_ID'];

    if (serverClientId != null && serverClientId.isNotEmpty) {
      // On iOS, pass clientId explicitly to prevent the Flutter plugin from
      // falling back to CLIENT_ID in GoogleService-Info.plist (Firebase project),
      // which differs from the OAuth project and causes invalid_audience errors.
      String? clientId;
      if (!kIsWeb && Platform.isIOS) {
        clientId = dotenv.env['GOOGLE_CLIENT_ID_IOS'];
      }

      return GoogleSignIn(
        scopes: const ['email', 'profile'],
        clientId: clientId,
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
  /// Returns a map with 'success' (bool) and optional 'message' (String)
  /// Throws [InvalidTokenException] if not authenticated
  static Future<Map<String, dynamic>> respondToEvent({
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

      if (resp.statusCode == 200) {
        return {'success': true};
      } else if (resp.statusCode == 409) {
        // Parse error message from response
        try {
          final body = json.decode(resp.body) as Map<String, dynamic>;
          final message = body['message'] as String?;
          return {
            'success': false,
            'message': message ?? 'This shift is no longer available',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'This shift is no longer available',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Failed to $response event',
        };
      }
    } catch (e) {
      _log('Failed to respond to event: $e', isError: true);
      return {
        'success': false,
        'message': 'Failed to $response event',
      };
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
  ///
  /// [source] or [locationSource] can be: 'manual', 'geofence', 'voice_assistant'
  /// Response may include gamification data: pointsEarned, newStreak, isNewRecord
  static Future<Map<String, dynamic>?> clockIn({
    required String eventId,
    String? role,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? source,
    String? locationSource,
  }) async {
    if (eventId.isEmpty) {
      throw ArgumentError('eventId cannot be empty');
    }

    final token = await getJwt();
    if (token == null) return null;

    // Use locationSource if provided, otherwise fall back to source
    final effectiveSource = locationSource ?? source;

    try {
      final body = <String, dynamic>{};
      if (role != null) body['role'] = role;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (accuracy != null) body['accuracy'] = accuracy;
      if (effectiveSource != null) body['source'] = effectiveSource;

      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/clock-in'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        ),
        operation: 'Clock in',
      );

      if (resp.statusCode == 200 ||
          resp.statusCode == 201 ||
          resp.statusCode == 409) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }

      // Handle geofence violation error
      if (resp.statusCode == 403) {
        final errorData = json.decode(resp.body) as Map<String, dynamic>;
        if (errorData['code'] == 'GEOFENCE_VIOLATION') {
          return errorData; // Return error data for UI to handle
        }
      }

      return null;
    } catch (e) {
      _log('Failed to clock in: $e', isError: true);
      return null;
    }
  }

  /// Clocks out the user from an event
  /// Returns the response data or null if not authenticated or request fails
  ///
  /// Response includes hoursWorked and autoClockOut fields
  static Future<Map<String, dynamic>?> clockOut({
    required String eventId,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    if (eventId.isEmpty) {
      throw ArgumentError('eventId cannot be empty');
    }

    final token = await getJwt();
    if (token == null) return null;

    try {
      final body = <String, dynamic>{};
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (accuracy != null) body['accuracy'] = accuracy;

      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/clock-out'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
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

  /// Gets the current user's gamification stats (points, streaks)
  /// Returns null if not authenticated or request fails
  static Future<Map<String, dynamic>?> getGamificationStats() async {
    final token = await getJwt();
    if (token == null) return null;

    try {
      final resp = await _makeRequest(
        request: () => http.get(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/users/me/gamification'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        operation: 'Get gamification stats',
      );
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _log('Failed to get gamification stats: $e', isError: true);
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
