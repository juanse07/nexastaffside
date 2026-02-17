import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../auth_service.dart';

/// Service for exporting staff shift data in multiple formats
class ExportService {
  static const _fileExtensions = {
    'csv': '.csv',
    'pdf': '.pdf',
    'xlsx': '.xlsx',
    'docx': '.docx',
  };

  static const _mimeTypes = {
    'csv': 'text/csv',
    'pdf': 'application/pdf',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  /// Export staff shifts in the specified format.
  ///
  /// For CSV: the backend returns raw text directly.
  /// For PDF/XLSX/DOCX: the backend calls the Python doc-service,
  /// uploads to R2, and returns a JSON with a presigned download URL.
  static Future<ExportResult> exportShifts({
    String format = 'csv',
    String period = 'month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        return ExportResult(success: false, error: 'Not authenticated');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final queryParams = <String, String>{
        'format': format,
        'period': period,
      };

      if (period == 'custom' && startDate != null && endDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('${AuthService.apiBaseUrl}/api/exports/staff-shifts')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        return ExportResult(
          success: false,
          error: 'Failed to generate export: ${response.statusCode}',
        );
      }

      if (format == 'csv') {
        // CSV: backend returns raw text content
        return ExportResult(success: true, csvContent: response.body);
      }

      // PDF/XLSX/DOCX: backend returns JSON { url, key, filename, contentType }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final downloadUrl = json['url'] as String?;
      final filename = json['filename'] as String? ?? 'export${_fileExtensions[format]}';

      if (downloadUrl == null) {
        return ExportResult(success: false, error: 'No download URL returned');
      }

      // Download the file from the presigned R2 URL
      final fileResponse = await http.get(Uri.parse(downloadUrl));
      if (fileResponse.statusCode != 200) {
        return ExportResult(
          success: false,
          error: 'Failed to download file: ${fileResponse.statusCode}',
        );
      }

      return ExportResult(
        success: true,
        fileBytes: fileResponse.bodyBytes,
        filename: filename,
        mimeType: _mimeTypes[format] ?? 'application/octet-stream',
      );
    } catch (e) {
      return ExportResult(success: false, error: 'Export error: $e');
    }
  }

  /// Share or download the exported file.
  /// Works for both CSV (text content) and binary files (PDF/XLSX).
  /// [origin] is required on iPad — pass the button's render box rect.
  /// Returns null on success, or an error message string on failure.
  static Future<String?> shareExport(ExportResult result, {Rect? origin}) async {
    if (kIsWeb) return 'Sharing not supported on web';

    if (result.fileBytes == null && result.csvContent == null) {
      return 'No export content to share';
    }

    final tempDir = await getTemporaryDirectory();
    final filename = result.filename ?? 'export.csv';
    final file = File('${tempDir.path}/$filename');

    if (result.fileBytes != null) {
      await file.writeAsBytes(result.fileBytes!);
    } else {
      await file.writeAsString(result.csvContent!);
    }

    final mimeType = result.mimeType ?? 'text/csv';

    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: 'Shift Export',
      sharePositionOrigin: origin,
    );

    return null;
  }
}

/// Result of an export operation
class ExportResult {
  final bool success;
  final String? csvContent;
  final Uint8List? fileBytes;
  final String? filename;
  final String? mimeType;
  final String? error;

  ExportResult({
    required this.success,
    this.csvContent,
    this.fileBytes,
    this.filename,
    this.mimeType,
    this.error,
  });
}
