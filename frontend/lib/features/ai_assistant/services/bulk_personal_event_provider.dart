import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../auth_service.dart';
import 'staff_extraction_service.dart';

/// Phases of the bulk import flow.
enum BulkPhase { selectFiles, extracting, preview, creating, complete }

/// Per-file status during extraction.
enum BulkFileStatus { pending, extracting, extracted, failed }

/// A single extracted event that the user can toggle/edit before creation.
class BulkExtractedEvent {
  Map<String, dynamic> data;
  bool isSelected;
  bool created;
  String? errorMessage;
  String? createdEventId;

  BulkExtractedEvent({
    required this.data,
    this.isSelected = true,
    this.created = false,
    this.errorMessage,
    this.createdEventId,
  });
}

/// Represents one file being processed in the bulk import.
class BulkFileItem {
  final File file;
  final String fileName;
  final bool isImage;
  final int fileSize;
  BulkFileStatus status;
  String? errorMessage;
  List<BulkExtractedEvent> extractedEvents;

  BulkFileItem({
    required this.file,
    required this.fileName,
    required this.isImage,
    required this.fileSize,
    this.status = BulkFileStatus.pending,
    this.errorMessage,
    List<BulkExtractedEvent>? extractedEvents,
  }) : extractedEvents = extractedEvents ?? [];

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Two-phase bulk import provider:
/// Phase 1: Extract events from all files → preview
/// Phase 2: User reviews/edits → create selected events
class BulkPersonalEventProvider extends ChangeNotifier {
  BulkPhase _phase = BulkPhase.selectFiles;
  List<BulkFileItem> _files = [];
  bool _isCancelled = false;
  bool _hitPaywall = false;

  // Getters
  BulkPhase get phase => _phase;
  List<BulkFileItem> get files => List.unmodifiable(_files);
  bool get hasFiles => _files.isNotEmpty;
  bool get hitPaywall => _hitPaywall;

  int get totalFiles => _files.length;

  List<BulkExtractedEvent> get allExtractedEvents =>
      _files.expand((f) => f.extractedEvents).toList();

  int get selectedCount =>
      allExtractedEvents.where((e) => e.isSelected).length;

  int get createdCount =>
      allExtractedEvents.where((e) => e.created).length;

  int get failedCount =>
      allExtractedEvents.where((e) => e.errorMessage != null && !e.created).length;

  int get extractedFileCount =>
      _files.where((f) => f.status == BulkFileStatus.extracted).length;

  int get totalExtractedEvents => allExtractedEvents.length;

  double get extractionProgress {
    if (_files.isEmpty) return 0;
    final done = _files.where((f) =>
        f.status == BulkFileStatus.extracted ||
        f.status == BulkFileStatus.failed).length;
    return done / _files.length;
  }

  // ── File management ──

  void addFiles(List<File> newFiles) {
    for (final file in newFiles) {
      final fileName = file.path.split('/').last;
      final ext = fileName.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'heic'].contains(ext);

      // Skip duplicates
      if (_files.any((f) => f.file.path == file.path)) continue;

      _files.add(BulkFileItem(
        file: file,
        fileName: fileName,
        isImage: isImage,
        fileSize: file.lengthSync(),
      ));
    }
    notifyListeners();
  }

  void removeFile(int index) {
    if (index >= 0 && index < _files.length) {
      _files.removeAt(index);
      notifyListeners();
    }
  }

  void clearAll() {
    _files.clear();
    _phase = BulkPhase.selectFiles;
    _isCancelled = false;
    _hitPaywall = false;
    notifyListeners();
  }

  void reset() {
    _files.clear();
    _phase = BulkPhase.selectFiles;
    _isCancelled = false;
    _hitPaywall = false;
    notifyListeners();
  }

  void cancel() {
    _isCancelled = true;
    notifyListeners();
  }

  /// Load pre-extracted events from a single file (e.g. from chat flow).
  /// Jumps directly to the preview phase, skipping file selection + extraction.
  void loadPreExtractedEvents({
    required File file,
    required List<Map<String, dynamic>> events,
  }) {
    final fileName = file.path.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'heic'].contains(ext);

    _files = [
      BulkFileItem(
        file: file,
        fileName: fileName,
        isImage: isImage,
        fileSize: file.lengthSync(),
        status: BulkFileStatus.extracted,
        extractedEvents: events
            .map((data) => BulkExtractedEvent(data: data))
            .toList(),
      ),
    ];
    _phase = BulkPhase.preview;
    notifyListeners();
  }

  // ── Phase 1: Extract all files ──

  Future<void> extractAllFiles() async {
    if (_files.isEmpty) return;
    _phase = BulkPhase.extracting;
    _isCancelled = false;
    notifyListeners();

    for (int i = 0; i < _files.length; i++) {
      if (_isCancelled) break;

      final item = _files[i];
      if (item.status != BulkFileStatus.pending) continue;

      item.status = BulkFileStatus.extracting;
      notifyListeners();

      try {
        List<Map<String, dynamic>>? events;
        if (item.isImage) {
          events = await StaffExtractionService.extractMultiFromImage(item.file);
        } else {
          events = await StaffExtractionService.extractMultiFromPdf(item.file);
        }

        if (events != null && events.isNotEmpty) {
          item.extractedEvents = events
              .map((data) => BulkExtractedEvent(data: data))
              .toList();
          item.status = BulkFileStatus.extracted;
        } else {
          item.status = BulkFileStatus.failed;
          item.errorMessage = 'No jobs found in this file';
        }
      } catch (e) {
        item.status = BulkFileStatus.failed;
        item.errorMessage = _formatError(e.toString());
      }

      notifyListeners();

      // Small delay between files to respect API rate limits
      if (!_isCancelled && i < _files.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    _phase = BulkPhase.preview;
    notifyListeners();
  }

  // ── Preview controls ──

  void toggleEvent(int fileIdx, int eventIdx) {
    if (fileIdx < _files.length &&
        eventIdx < _files[fileIdx].extractedEvents.length) {
      final event = _files[fileIdx].extractedEvents[eventIdx];
      event.isSelected = !event.isSelected;
      notifyListeners();
    }
  }

  void selectAll() {
    for (final f in _files) {
      for (final e in f.extractedEvents) {
        e.isSelected = true;
      }
    }
    notifyListeners();
  }

  void deselectAll() {
    for (final f in _files) {
      for (final e in f.extractedEvents) {
        e.isSelected = false;
      }
    }
    notifyListeners();
  }

  void updateEventData(int fileIdx, int eventIdx, Map<String, dynamic> data) {
    if (fileIdx < _files.length &&
        eventIdx < _files[fileIdx].extractedEvents.length) {
      _files[fileIdx].extractedEvents[eventIdx].data = data;
      notifyListeners();
    }
  }

  /// Apply shared field values to all selected events.
  /// Skips 'date' to preserve each event's individual date.
  void applyBulkEdit(Map<String, dynamic> edits) {
    final safeEdits = Map<String, dynamic>.from(edits)..remove('date');
    for (final file in _files) {
      for (final event in file.extractedEvents) {
        if (!event.isSelected) continue;
        for (final entry in safeEdits.entries) {
          event.data[entry.key] = entry.value;
        }
      }
    }
    notifyListeners();
  }

  // ── Phase 2: Create selected events ──

  Future<void> createSelectedEvents() async {
    _phase = BulkPhase.creating;
    _isCancelled = false;
    _hitPaywall = false;
    notifyListeners();

    final jwt = await AuthService.getJwt();
    if (jwt == null) return;

    final apiBase = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    final pathPfx = _apiPathPrefix;
    final url = Uri.parse('$apiBase$pathPfx/personal-events');

    for (final file in _files) {
      for (final event in file.extractedEvents) {
        if (_isCancelled) break;
        if (!event.isSelected || event.created) continue;

        try {
          final payload = _sanitizePayload(event.data);
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode(payload),
          );

          if (response.statusCode == 201 || response.statusCode == 200) {
            final body = jsonDecode(response.body);
            event.created = true;
            event.createdEventId =
                body['_id']?.toString() ?? body['id']?.toString();
          } else if (response.statusCode == 402) {
            event.errorMessage = 'Subscription required';
            _hitPaywall = true;
            _isCancelled = true;
          } else {
            final msg = _tryParseError(response.body);
            event.errorMessage = msg;
          }
        } catch (e) {
          event.errorMessage = _formatError(e.toString());
        }

        notifyListeners();

        // Small delay between creations
        if (!_isCancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
      if (_isCancelled) break;
    }

    _phase = BulkPhase.complete;
    notifyListeners();
  }

  // ── Helpers ──

  String get _apiPathPrefix {
    final raw = (dotenv.env['API_PATH_PREFIX'] ?? '').trim();
    if (raw.isEmpty) return '';
    final withLead = raw.startsWith('/') ? raw : '/$raw';
    return withLead.endsWith('/')
        ? withLead.substring(0, withLead.length - 1)
        : withLead;
  }

  /// Normalize AI-extracted field names to the personal-events API format.
  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> raw) {
    final p = <String, dynamic>{};

    // Date
    final dateRaw = raw['date']?.toString();
    if (dateRaw != null && dateRaw.isNotEmpty) {
      final d = DateTime.tryParse(dateRaw);
      p['date'] = d != null
          ? DateFormat('yyyy-MM-dd').format(d)
          : dateRaw.split('T').first;
    } else {
      p['date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    // Times — normalize HH:mm, default to 9-5 when AI didn't extract times
    p['startTime'] = _normalizeTime(raw['startTime'] ?? raw['start_time']) ?? '09:00';
    p['endTime'] = _normalizeTime(raw['endTime'] ?? raw['end_time']) ?? '17:00';

    // Optional fields
    final loc = raw['location'] ?? raw['venue_name'];
    if (loc != null && loc.toString().trim().isNotEmpty) {
      p['location'] = loc.toString().trim();
    }

    final notes = raw['notes'];
    if (notes != null && notes.toString().trim().isNotEmpty) {
      p['notes'] = notes.toString().trim();
    }

    final role = raw['role'] ?? raw['personal_role'];
    if (role != null && role.toString().trim().isNotEmpty) {
      p['role'] = role.toString().trim();
    }

    final client = raw['client'] ?? raw['personal_client'];
    if (client != null && client.toString().trim().isNotEmpty) {
      p['client'] = client.toString().trim();
    }

    // Title — use extracted title, or build from role/client/location/date
    final rawTitle = raw['title'] ?? raw['event_name'];
    if (rawTitle != null && rawTitle.toString().trim().isNotEmpty) {
      p['title'] = rawTitle.toString().trim();
    } else {
      final parts = <String>[
        if (p['role'] != null) p['role'] as String,
        if (p['client'] != null) '@ ${p['client']}',
        if (p['role'] == null && p['client'] == null && p['location'] != null)
          p['location'] as String,
      ];
      p['title'] = parts.isNotEmpty ? parts.join(' ') : p['date'] as String;
    }

    final rate = raw['hourlyRate'] ?? raw['hourly_rate'];
    if (rate != null) {
      final rateNum = rate is num ? rate.toDouble() : double.tryParse(rate.toString());
      if (rateNum != null && rateNum > 0) {
        p['hourlyRate'] = rateNum;
      }
    }

    return p;
  }

  String? _normalizeTime(dynamic val) {
    if (val == null) return null;
    final s = val.toString();
    if (s.isEmpty) return null;
    // If ISO datetime, extract HH:mm
    if (s.contains('T') && s.length > 10) {
      final match = RegExp(r'T(\d{2}:\d{2})').firstMatch(s);
      if (match != null) return match.group(1);
    }
    // Already HH:mm or HH:mm:ss
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) {
      return s.substring(0, s.indexOf(':') + 3);
    }
    return null;
  }

  String _tryParseError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['message']?.toString() ?? 'Unknown error';
    } catch (_) {
      return 'Server error';
    }
  }

  String _formatError(String error) {
    if (error.contains('429') || error.contains('rate limit')) {
      return 'Rate limit reached. Try again later.';
    }
    if (error.length > 50) return '${error.substring(0, 47)}...';
    return error.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _files.clear();
    super.dispose();
  }
}
