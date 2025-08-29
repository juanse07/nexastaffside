import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static const _jwtStorageKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  static String get _apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
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
      await GoogleSignIn(scopes: ['email', 'profile']).signOut();
    } catch (_) {}
  }

  static Future<String?> getJwt() => _storage.read(key: _jwtStorageKey);

  static Future<void> _saveJwt(String token) =>
      _storage.write(key: _jwtStorageKey, value: token);

  static Future<bool> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
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
}
