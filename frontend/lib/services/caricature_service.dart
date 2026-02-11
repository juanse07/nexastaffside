import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// A role option returned from the backend.
class CaricatureRole {
  CaricatureRole({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
    required this.locked,
  });

  final String id;
  final String label;
  final String icon;
  final String category;
  final bool locked;

  factory CaricatureRole.fromMap(Map<String, dynamic> map) {
    return CaricatureRole(
      id: map['id'] as String,
      label: map['label'] as String,
      icon: map['icon'] as String? ?? 'person',
      category: map['category'] as String? ?? 'Other',
      locked: map['locked'] as bool? ?? false,
    );
  }
}

/// An art style option returned from the backend.
class CaricatureArtStyle {
  CaricatureArtStyle({
    required this.id,
    required this.label,
    required this.icon,
    required this.locked,
  });

  final String id;
  final String label;
  final String icon;
  final bool locked;

  factory CaricatureArtStyle.fromMap(Map<String, dynamic> map) {
    return CaricatureArtStyle(
      id: map['id'] as String,
      label: map['label'] as String,
      icon: map['icon'] as String? ?? 'brush',
      locked: map['locked'] as bool? ?? false,
    );
  }
}

/// Response from GET /api/caricature/styles
class StylesResponse {
  StylesResponse({required this.roles, required this.artStyles});
  final List<CaricatureRole> roles;
  final List<CaricatureArtStyle> artStyles;
}

/// Result of a caricature generation.
class CaricatureResult {
  CaricatureResult({required this.url, required this.remaining});
  final String url;
  final int remaining;
}

/// Service for AI caricature generation via the backend API.
/// Uses raw http package (consistent with staff app architecture).
class CaricatureService {
  static const _jwtStorageKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  static String get _apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    if (!kIsWeb && Platform.isAndroid) {
      if (raw.contains('127.0.0.1')) return raw.replaceAll('127.0.0.1', '10.0.2.2');
      if (raw.contains('localhost')) return raw.replaceAll('localhost', '10.0.2.2');
    }
    return raw;
  }

  static String get _apiPathPrefix {
    final raw = (dotenv.env['API_PATH_PREFIX'] ?? '').trim();
    if (raw.isEmpty) return '';
    final withLead = raw.startsWith('/') ? raw : '/$raw';
    return withLead.endsWith('/') ? withLead.substring(0, withLead.length - 1) : withLead;
  }

  static void _log(String message, {bool isError = false}) {
    if (kDebugMode) {
      developer.log(message, name: 'CaricatureService', error: isError ? message : null);
    }
  }

  static Future<String?> _getJwt() async {
    try {
      return await _storage.read(key: _jwtStorageKey);
    } catch (e) {
      _log('Failed to read JWT: $e', isError: true);
      return null;
    }
  }

  /// Fetch available roles and art styles.
  static Future<StylesResponse> getStyles() async {
    final token = await _getJwt();
    if (token == null) throw Exception('Not authenticated');

    final resp = await http.get(
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/caricature/styles'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load styles');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final rolesRaw = data['roles'] as List<dynamic>? ?? [];
    final artStylesRaw = data['artStyles'] as List<dynamic>? ?? [];

    return StylesResponse(
      roles: rolesRaw.map((r) => CaricatureRole.fromMap(r as Map<String, dynamic>)).toList(),
      artStyles: artStylesRaw.map((s) => CaricatureArtStyle.fromMap(s as Map<String, dynamic>)).toList(),
    );
  }

  /// Generate a caricature with the given role and art style.
  /// Extended timeout since image generation takes 10-20 seconds.
  static Future<CaricatureResult> generate(String roleId, String artStyleId) async {
    final token = await _getJwt();
    if (token == null) throw Exception('Not authenticated');

    _log('Generating caricature: role=$roleId, style=$artStyleId');

    final resp = await http.post(
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/caricature/generate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'role': roleId, 'artStyle': artStyleId}),
    ).timeout(const Duration(seconds: 90));

    final data = json.decode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode == 429) {
      throw Exception(data['message'] ?? 'Daily limit reached');
    }
    if (resp.statusCode == 400) {
      throw Exception(data['message'] ?? 'Invalid request');
    }
    if (resp.statusCode != 200) {
      throw Exception(data['message'] ?? 'Generation failed');
    }

    _log('Caricature generated: ${data['url']}');

    return CaricatureResult(
      url: data['url'] as String,
      remaining: data['remaining'] as int? ?? 0,
    );
  }
}
