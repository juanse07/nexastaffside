import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../auth_service.dart';

/// Lightweight service for extracting personal event data from images and PDFs.
/// Calls POST /api/ai/staff/extract on the backend.
class StaffExtractionService {
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

  /// Process an image file → base64 → POST /api/ai/staff/extract
  static Future<Map<String, dynamic>?> extractFromImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Input = base64Encode(bytes);
    return _callExtractEndpoint(base64Input, isImage: true);
  }

  /// Process a PDF file → text extraction → POST /api/ai/staff/extract
  static Future<Map<String, dynamic>?> extractFromPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);

    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      final pageText = extractor.extractText(startPageIndex: i);
      if (pageText.isNotEmpty) {
        buffer.writeln(pageText);
      }
    }
    document.dispose();

    final text = buffer.toString().trim();
    if (text.isEmpty) return null;

    return _callExtractEndpoint(text, isImage: false);
  }

  // ── Multi-event extraction (bulk import) ──

  /// Process an image file → base64 → POST with multi=true
  static Future<List<Map<String, dynamic>>?> extractMultiFromImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Input = base64Encode(bytes);
    return _callExtractEndpointMulti(base64Input, isImage: true);
  }

  /// Process a PDF file → text → POST with multi=true
  static Future<List<Map<String, dynamic>>?> extractMultiFromPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);

    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      final pageText = extractor.extractText(startPageIndex: i);
      if (pageText.isNotEmpty) buffer.writeln(pageText);
    }
    document.dispose();

    final text = buffer.toString().trim();
    if (text.isEmpty) return null;

    return _callExtractEndpointMulti(text, isImage: false);
  }

  /// Multi-event API call — sends multi=true and parses response as List.
  static Future<List<Map<String, dynamic>>?> _callExtractEndpointMulti(
    String input, {
    bool isImage = false,
  }) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null) return null;

    final url = Uri.parse('$_apiBaseUrl$_apiPathPrefix/ai/staff/extract');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({
        'input': input,
        'isImage': isImage,
        'multi': true,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final extracted = data['extracted'];
      if (extracted is List) {
        return extracted.cast<Map<String, dynamic>>();
      }
      // Single object returned — wrap in list
      if (extracted is Map<String, dynamic>) {
        return [extracted];
      }
      return null;
    }

    print('[StaffExtractionService] Multi error ${response.statusCode}: ${response.body}');
    return null;
  }

  // ── Single-event extraction (existing) ──

  /// Raw API call to the staff extraction endpoint.
  static Future<Map<String, dynamic>?> _callExtractEndpoint(
    String input, {
    bool isImage = false,
  }) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null) return null;

    final url = Uri.parse('$_apiBaseUrl$_apiPathPrefix/ai/staff/extract');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({
        'input': input,
        'isImage': isImage,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['extracted'] as Map<String, dynamic>?;
    }

    print('[StaffExtractionService] Error ${response.statusCode}: ${response.body}');
    return null;
  }
}
