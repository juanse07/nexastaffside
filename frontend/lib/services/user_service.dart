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
  final String? phoneNumber;

  UserProfile({
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.name,
    this.picture,
    this.appId,
    this.phoneNumber,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString(),
      email: map['email']?.toString(),
      firstName: map['firstName']?.toString(),
      lastName: map['lastName']?.toString(),
      name: map['name']?.toString(),
      picture: map['picture']?.toString(),
      appId: map['appId']?.toString(),
      phoneNumber: map['phoneNumber']?.toString(),
    );
  }
}

class UserService {
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
    String? phoneNumber,
    String? appId,
    String? picture,
  }) async {
    final token = await _getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final payload = <String, dynamic>{};
    if (firstName != null && firstName.isNotEmpty) payload['firstName'] = firstName;
    if (lastName != null && lastName.isNotEmpty) payload['lastName'] = lastName;
    if (phoneNumber != null && phoneNumber.isNotEmpty) payload['phoneNumber'] = phoneNumber;
    if (appId != null && appId.isNotEmpty) payload['appId'] = appId;
    if (picture != null && picture.isNotEmpty) payload['picture'] = picture;

    _log('Update payload: ${jsonEncode(payload)}');

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
}
