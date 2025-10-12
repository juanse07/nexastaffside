import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UserProfile {
  final String? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? name;
  final String? picture;
  final String? appId;

  UserProfile({
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.name,
    this.picture,
    this.appId,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString(),
      email: map['email']?.toString(),
      firstName: map['first_name']?.toString(),
      lastName: map['last_name']?.toString(),
      name: map['name']?.toString(),
      picture: map['picture']?.toString(),
      appId: map['app_id']?.toString(),
    );
  }
}

class UserService {
  static const _jwtStorageKey = 'auth_jwt';
  static const _preferredRolesKey = 'preferred_roles';
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
        developer.log(message, name: 'UserService', error: message);
      } else {
        developer.log(message, name: 'UserService');
      }
    }
  }

  /// Gets the stored JWT token
  static Future<String?> _getJwt() async {
    try {
      return await _storage.read(key: _jwtStorageKey);
    } catch (e) {
      _log('Failed to read JWT: $e', isError: true);
      return null;
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
    } catch (e) {
      _log('$operation: Request failed: $e', isError: true);
      rethrow;
    }
  }

  /// Gets the current user's profile
  static Future<UserProfile> getMe() async {
    final token = await _getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final resp = await _makeRequest(
      request: () => http.get(
        Uri.parse('$_apiBaseUrl$_apiPathPrefix/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      operation: 'Get user profile',
    );

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      return UserProfile.fromMap(data);
    } else {
      throw Exception('Failed to load profile: ${resp.statusCode}');
    }
  }

  /// Updates the current user's profile
  static Future<UserProfile> updateMe({
    String? firstName,
    String? lastName,
    String? appId,
    String? picture,
  }) async {
    final token = await _getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final payload = <String, dynamic>{};
    if (firstName != null) payload['first_name'] = firstName;
    if (lastName != null) payload['last_name'] = lastName;
    if (appId != null) payload['app_id'] = appId;
    if (picture != null) payload['picture'] = picture;

    final resp = await _makeRequest(
      request: () => http.patch(
        Uri.parse('$_apiBaseUrl$_apiPathPrefix/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ),
      operation: 'Update user profile',
    );

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      return UserProfile.fromMap(data);
    } else {
      final errorBody = resp.body;
      try {
        final errorData = json.decode(errorBody) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to update profile');
      } catch (_) {
        throw Exception('Failed to update profile: ${resp.statusCode}');
      }
    }
  }

  /// Gets the user's preferred roles from local storage
  static Future<Set<String>> getPreferredRoles() async {
    try {
      final rolesJson = await _storage.read(key: _preferredRolesKey);
      if (rolesJson == null || rolesJson.isEmpty) {
        return {}; // Empty set means show all roles
      }
      final rolesList = json.decode(rolesJson) as List<dynamic>;
      return rolesList.map((r) => r.toString()).toSet();
    } catch (e) {
      _log('Failed to read preferred roles: $e', isError: true);
      return {}; // Return empty set on error (show all)
    }
  }

  /// Saves the user's preferred roles to local storage
  static Future<void> setPreferredRoles(Set<String> roles) async {
    try {
      final rolesJson = json.encode(roles.toList());
      await _storage.write(key: _preferredRolesKey, value: rolesJson);
      _log('Preferred roles saved: ${roles.length} roles');
    } catch (e) {
      _log('Failed to save preferred roles: $e', isError: true);
      // Try to clear and retry once
      try {
        await _storage.deleteAll();
        final rolesJson = json.encode(roles.toList());
        await _storage.write(key: _preferredRolesKey, value: rolesJson);
        _log('Successfully saved roles after clearing storage');
      } catch (retryError) {
        _log('Failed to save roles even after clearing: $retryError', isError: true);
        rethrow;
      }
    }
  }

  /// Clears the user's preferred roles (will show all roles)
  static Future<void> clearPreferredRoles() async {
    try {
      await _storage.delete(key: _preferredRolesKey);
      _log('Preferred roles cleared');
    } catch (e) {
      _log('Failed to clear preferred roles: $e', isError: true);
      rethrow;
    }
  }

  /// Fetches all available roles from the API
  static Future<List<String>> getAllRoles() async {
    try {
      final token = await _getJwt();
      final headers = <String, String>{};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final url = '$_apiBaseUrl$_apiPathPrefix/roles';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final roles = data
            .map((r) => (r as Map<String, dynamic>)['name']?.toString())
            .where((name) => name != null && name.isNotEmpty)
            .cast<String>()
            .toList();
        _log('Fetched ${roles.length} roles from API');
        return roles;
      } else {
        _log('Failed to fetch roles: ${response.statusCode}', isError: true);
        return [];
      }
    } catch (e) {
      _log('Failed to fetch roles: $e', isError: true);
      return [];
    }
  }
}
