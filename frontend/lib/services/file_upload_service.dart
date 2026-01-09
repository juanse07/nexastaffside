import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Result of a file upload operation
class UploadResult {
  final String url;
  final String? key;
  final String? filename;
  final int? size;

  UploadResult({
    required this.url,
    this.key,
    this.filename,
    this.size,
  });

  factory UploadResult.fromMap(Map<String, dynamic> map) {
    return UploadResult(
      url: map['url'] as String,
      key: map['key'] as String?,
      filename: map['filename'] as String?,
      size: map['size'] as int?,
    );
  }
}

/// Service for uploading files to Cloudflare R2 via the backend API
class FileUploadService {
  static const _jwtStorageKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();
  static const _requestTimeout = Duration(seconds: 60); // Longer timeout for uploads

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
        developer.log(message, name: 'FileUploadService', error: message);
      } else {
        developer.log(message, name: 'FileUploadService');
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

  /// Gets the MIME type from a filename
  static MediaType? _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return null;
    }
  }

  /// Uploads a profile picture from a File
  /// Returns the public URL of the uploaded image
  static Future<String> uploadProfilePicture(File file) async {
    final token = await _getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final filename = file.path.split('/').last;
    _log('Uploading profile picture: $filename');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/upload/profile-picture'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: filename,
        contentType: _getMimeType(filename),
      ),
    );

    try {
      final streamedResponse = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      _log('Upload response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final url = data['url'] as String;
        _log('Profile picture uploaded: $url');
        return url;
      } else {
        final errorBody = response.body;
        try {
          final errorData = json.decode(errorBody) as Map<String, dynamic>;
          throw Exception(errorData['message'] ?? 'Failed to upload profile picture');
        } catch (_) {
          throw Exception('Failed to upload profile picture: ${response.statusCode}');
        }
      }
    } catch (e) {
      _log('Upload failed: $e', isError: true);
      rethrow;
    }
  }

  /// Uploads a profile picture from bytes (useful for web or cropped images)
  static Future<String> uploadProfilePictureBytes(
    Uint8List bytes,
    String filename,
  ) async {
    final token = await _getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    _log('Uploading profile picture bytes: $filename (${bytes.length} bytes)');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_apiBaseUrl$_apiPathPrefix/upload/profile-picture'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: _getMimeType(filename),
      ),
    );

    try {
      final streamedResponse = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      _log('Upload response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final url = data['url'] as String;
        _log('Profile picture uploaded: $url');
        return url;
      } else {
        final errorBody = response.body;
        try {
          final errorData = json.decode(errorBody) as Map<String, dynamic>;
          throw Exception(errorData['message'] ?? 'Failed to upload profile picture');
        } catch (_) {
          throw Exception('Failed to upload profile picture: ${response.statusCode}');
        }
      }
    } catch (e) {
      _log('Upload failed: $e', isError: true);
      rethrow;
    }
  }

  /// Gets a presigned URL for downloading a private file
  static Future<String> getPresignedUrl(
    String key, {
    int expiresInSeconds = 3600,
  }) async {
    final token = await _getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_apiBaseUrl$_apiPathPrefix/upload/presigned-url')
        .replace(queryParameters: {
      'key': key,
      'expiresIn': expiresInSeconds.toString(),
    });

    try {
      final response = await http
          .get(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['url'] as String;
      } else {
        throw Exception('Failed to get download URL: ${response.statusCode}');
      }
    } catch (e) {
      _log('Failed to get presigned URL: $e', isError: true);
      rethrow;
    }
  }

  /// Deletes a file from storage
  static Future<void> deleteFile(String key) async {
    final token = await _getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$_apiBaseUrl$_apiPathPrefix/upload/file'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'key': key}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete file: ${response.statusCode}');
      }

      _log('File deleted: $key');
    } catch (e) {
      _log('Failed to delete file: $e', isError: true);
      rethrow;
    }
  }
}
