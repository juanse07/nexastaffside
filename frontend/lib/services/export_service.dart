import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for exporting staff shift data as CSV
class ExportService {
  static const _storage = FlutterSecureStorage();
  static String get _baseUrl => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.nexapymesoft.com',
  );
  static String get _apiUrl => '$_baseUrl/api';

  /// Get auth headers for API requests
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Export staff shifts as CSV
  static Future<ExportResult> exportShiftsCsv({
    String period = 'month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'format': 'csv',
        'period': period,
      };

      if (period == 'custom' && startDate != null && endDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$_apiUrl/exports/staff-shifts')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return ExportResult(success: true, content: response.body);
      }

      return ExportResult(
        success: false,
        error: 'Failed to generate export: ${response.statusCode}',
      );
    } catch (e) {
      return ExportResult(success: false, error: 'Export error: $e');
    }
  }

  /// Share or download the CSV file
  static Future<bool> shareExport(String csvContent, String filename) async {
    try {
      if (kIsWeb) {
        // For web, we'd need to trigger a download
        // This requires additional web-specific implementation
        return false;
      }

      // For mobile, save to temp and share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Shift Export',
      );

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Result of an export operation
class ExportResult {
  final bool success;
  final String? content;
  final String? error;

  ExportResult({
    required this.success,
    this.content,
    this.error,
  });
}
