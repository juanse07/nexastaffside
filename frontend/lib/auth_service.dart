import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static const _jwtStorageKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

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

  static Future<void> signOut() async {
    await _storage.delete(key: _jwtStorageKey);
    try {
      await _googleSignIn().signOut();
    } catch (_) {}
  }

  static Future<String?> getJwt() => _storage.read(key: _jwtStorageKey);

  static Future<void> _saveJwt(String token) =>
      _storage.write(key: _jwtStorageKey, value: token);

  static Future<bool> signInWithGoogle() async {
    final googleSignIn = _googleSignIn();
    final account = await googleSignIn.signIn();
    if (account == null) return false;
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) return false;

    final resp = await http.post(
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (resp.statusCode == 200) {
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final token = body['token']?.toString();
      if (token != null) {
        await _saveJwt(token);
        return true;
      }
    }
    return false;
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

  static Future<bool> signInWithApple() async {
    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        return false;
      }
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) return false;

      final resp = await http.post(
        Uri.parse('$_apiBaseUrl$_apiPathPrefix/auth/apple'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identityToken': identityToken}),
      );
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final token = body['token']?.toString();
        if (token != null) {
          await _saveJwt(token);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> respondToEvent({
    required String eventId,
    required String response,
    String? role,
  }) async {
    final token = await getJwt();
    if (token == null) return false;
    final resp = await http.post(
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/respond'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'response': response, if (role != null) 'role': role}),
    );
    return resp.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> getMyAttendanceStatus({
    required String eventId,
  }) async {
    final token = await getJwt();
    if (token == null) return null;
    final resp = await http.get(
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/attendance/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> clockIn({
    required String eventId,
    String? role,
  }) async {
    final token = await getJwt();
    if (token == null) return null;
    final resp = await http.post(
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/clock-in'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({if (role != null) 'role': role}),
    );
    if (resp.statusCode == 200 ||
        resp.statusCode == 201 ||
        resp.statusCode == 409) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> clockOut({
    required String eventId,
  }) async {
    final token = await getJwt();
    if (token == null) return null;
    final resp = await http.post(
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/$eventId/clock-out'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }

  // Availability management
  static Future<List<Map<String, dynamic>>> getAvailability() async {
    print('🔥 AVAILABILITY DEBUG 🔥 Starting getAvailability()');
    print('🔥 AVAILABILITY DEBUG 🔥 API Base URL: $_apiBaseUrl');
    print('🔥 AVAILABILITY DEBUG 🔥 API Path Prefix: $_apiPathPrefix');

    final token = await getJwt();
    if (token == null) {
      print('🔥 AVAILABILITY DEBUG 🔥 No JWT token found');
      return [];
    }

    final url = '$_apiBaseUrl$_apiPathPrefix/events/availability';
    print('🔥 AVAILABILITY DEBUG 🔥 Making GET request to: $url');

    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('🔥 AVAILABILITY DEBUG 🔥 Response status: ${resp.statusCode}');
      print('🔥 AVAILABILITY DEBUG 🔥 Response headers: ${resp.headers}');
      print('🔥 AVAILABILITY DEBUG 🔥 Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        print('🔥 AVAILABILITY DEBUG 🔥 Parsed data: $data');
        return data.cast<Map<String, dynamic>>();
      } else {
        print(
          '🔥 AVAILABILITY DEBUG 🔥 Error: Status ${resp.statusCode} - ${resp.body}',
        );
      }
    } catch (e) {
      print('🔥 AVAILABILITY DEBUG 🔥 Exception: $e');
    }
    return [];
  }

  static Future<bool> setAvailability({
    required String date,
    required String startTime,
    required String endTime,
    required String status,
  }) async {
    print('🔥 AVAILABILITY DEBUG 🔥 Starting setAvailability()');
    print(
      '🔥 AVAILABILITY DEBUG 🔥 Parameters: date=$date, startTime=$startTime, endTime=$endTime, status=$status',
    );

    final token = await getJwt();
    if (token == null) {
      print('🔥 AVAILABILITY DEBUG 🔥 No JWT token found');
      return false;
    }

    final url = '$_apiBaseUrl$_apiPathPrefix/events/availability';
    final body = {
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
    };

    print('🔥 AVAILABILITY DEBUG 🔥 Making POST request to: $url');
    print('🔥 AVAILABILITY DEBUG 🔥 Request body: ${jsonEncode(body)}');

    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('🔥 AVAILABILITY DEBUG 🔥 Response status: ${resp.statusCode}');
      print('🔥 AVAILABILITY DEBUG 🔥 Response headers: ${resp.headers}');
      print('🔥 AVAILABILITY DEBUG 🔥 Response body: ${resp.body}');

      return resp.statusCode == 200;
    } catch (e) {
      print('🔥 AVAILABILITY DEBUG 🔥 Exception: $e');
      return false;
    }
  }

  static Future<bool> deleteAvailability({required String id}) async {
    print('🔥 AVAILABILITY DEBUG 🔥 Starting deleteAvailability()');
    print('🔥 AVAILABILITY DEBUG 🔥 ID: $id');

    final token = await getJwt();
    if (token == null) {
      print('🔥 AVAILABILITY DEBUG 🔥 No JWT token found');
      return false;
    }

    final url = '$_apiBaseUrl$_apiPathPrefix/events/availability/$id';
    print('🔥 AVAILABILITY DEBUG 🔥 Making DELETE request to: $url');

    try {
      final resp = await http.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('🔥 AVAILABILITY DEBUG 🔥 Response status: ${resp.statusCode}');
      print('🔥 AVAILABILITY DEBUG 🔥 Response headers: ${resp.headers}');
      print('🔥 AVAILABILITY DEBUG 🔥 Response body: ${resp.body}');

      return resp.statusCode == 200;
    } catch (e) {
      print('🔥 AVAILABILITY DEBUG 🔥 Exception: $e');
      return false;
    }
  }
}
