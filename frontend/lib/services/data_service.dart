import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Enhanced data service with smart caching and efficient refresh mechanisms
class DataService extends ChangeNotifier {
  static const String _eventsStorageKey = 'cached_events';
  static const String _lastFetchKey = 'last_fetch_timestamp';
  static const String _availabilityStorageKey = 'cached_availability';
  static const String _lastAvailabilityFetchKey = 'last_availability_fetch';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Cache duration in minutes - adjust based on your needs
  static const int _cacheExpiryMinutes = 5;
  static const int _backgroundRefreshMinutes = 2;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _availability = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _lastError;
  DateTime? _lastFetch;
  DateTime? _lastAvailabilityFetch;
  Timer? _backgroundRefreshTimer;

  // Getters
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  List<Map<String, dynamic>> get availability =>
      List.unmodifiable(_availability);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;
  DateTime? get lastFetch => _lastFetch;
  bool get hasData => _events.isNotEmpty;

  // Check if data is fresh enough to avoid unnecessary requests
  bool get isDataFresh {
    if (_lastFetch == null) return false;
    final now = DateTime.now();
    final diff = now.difference(_lastFetch!);
    return diff.inMinutes < _cacheExpiryMinutes;
  }

  bool get isAvailabilityFresh {
    if (_lastAvailabilityFetch == null) return false;
    final now = DateTime.now();
    final diff = now.difference(_lastAvailabilityFetch!);
    return diff.inMinutes < _cacheExpiryMinutes;
  }

  static String get _apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    if (!kIsWeb && Platform.isAndroid) {
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

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    await _loadCachedData();
    _startBackgroundRefresh();
  }

  /// Load cached data from secure storage
  Future<void> _loadCachedData() async {
    try {
      // Load cached events
      final cachedEvents = await _storage.read(key: _eventsStorageKey);
      if (cachedEvents != null) {
        final data = json.decode(cachedEvents) as List<dynamic>;
        _events = data.cast<Map<String, dynamic>>();
      }

      // Load last fetch timestamp
      final lastFetchStr = await _storage.read(key: _lastFetchKey);
      if (lastFetchStr != null) {
        _lastFetch = DateTime.tryParse(lastFetchStr);
      }

      // Load cached availability
      final cachedAvailability = await _storage.read(
        key: _availabilityStorageKey,
      );
      if (cachedAvailability != null) {
        final data = json.decode(cachedAvailability) as List<dynamic>;
        _availability = data.cast<Map<String, dynamic>>();
      }

      // Load last availability fetch timestamp
      final lastAvailabilityStr = await _storage.read(
        key: _lastAvailabilityFetchKey,
      );
      if (lastAvailabilityStr != null) {
        _lastAvailabilityFetch = DateTime.tryParse(lastAvailabilityStr);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  /// Cache data to secure storage
  Future<void> _cacheEvents(List<Map<String, dynamic>> events) async {
    try {
      await _storage.write(key: _eventsStorageKey, value: json.encode(events));
      await _storage.write(
        key: _lastFetchKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error caching events: $e');
    }
  }

  /// Cache availability data to secure storage
  Future<void> _cacheAvailability(
    List<Map<String, dynamic>> availability,
  ) async {
    try {
      await _storage.write(
        key: _availabilityStorageKey,
        value: json.encode(availability),
      );
      await _storage.write(
        key: _lastAvailabilityFetchKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error caching availability: $e');
    }
  }

  /// Fetch events from server with delta sync support
  Future<void> _fetchEvents({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _lastError = null;
      notifyListeners();
    }

    try {
      // Build URL with delta sync support
      final lastSyncTimestamp = await _storage.read(key: 'last_sync_events');
      final uri = Uri.parse('$_apiBaseUrl$_apiPathPrefix/events');
      final uriWithParams = lastSyncTimestamp != null
          ? uri.replace(queryParameters: {'lastSync': lastSyncTimestamp})
          : uri;

      final token = await _storage.read(key: 'auth_jwt');
      final headers = <String, String>{};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(uriWithParams, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle both legacy (List) and new delta sync (Map) response formats
        List<dynamic> eventsData;
        String? serverTimestamp;
        bool isDeltaSync = false;

        if (responseData is List) {
          // Legacy format: direct array
          eventsData = responseData;
          serverTimestamp = DateTime.now().toIso8601String();
        } else if (responseData is Map<String, dynamic>) {
          // New delta sync format
          eventsData = (responseData['events'] ?? []) as List<dynamic>;
          serverTimestamp = responseData['serverTimestamp'] as String?;
          isDeltaSync = responseData['deltaSync'] == true;
        } else {
          throw Exception('Unexpected response format');
        }

        final userKey = _decodeUserKeyFromToken(token);
        final newEvents = _filterEventsForAudience(
          eventsData.cast<Map<String, dynamic>>(),
          userKey,
        );

        // Delta sync: merge changes with existing events
        if (isDeltaSync && lastSyncTimestamp != null) {
          debugPrint('Delta sync: ${newEvents.length} changes received');
          _events = _mergeEvents(_events, newEvents);
        } else {
          // Full sync: replace all events
          debugPrint('Full sync: ${newEvents.length} events received');
          _events = newEvents;
        }

        _lastFetch = DateTime.now();
        await _cacheEvents(_events);

        // Save server timestamp for next delta sync
        if (serverTimestamp != null) {
          await _storage.write(key: 'last_sync_events', value: serverTimestamp);
        }

        if (!silent) {
          notifyListeners();
        }

        _lastError = null;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _lastError = 'Failed to fetch events: $e';
      debugPrint(_lastError);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Merge changed events with existing events (for delta sync)
  List<Map<String, dynamic>> _mergeEvents(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> changes,
  ) {
    // Create a map of existing events by ID
    final Map<String, Map<String, dynamic>> eventMap = {};
    for (final event in existing) {
      final id = event['_id'] ?? event['id'];
      if (id != null) {
        eventMap[id.toString()] = event;
      }
    }

    // Apply changes (updates and new inserts)
    for (final change in changes) {
      final id = change['_id'] ?? change['id'];
      if (id != null) {
        eventMap[id.toString()] = change;
      }
    }

    return eventMap.values.toList();
  }

  /// Fetch availability from server with JWT token
  Future<void> _fetchAvailability({bool silent = false}) async {
    try {
      final token = await _storage.read(key: 'auth_jwt');
      if (token == null) return;

      final url = '$_apiBaseUrl$_apiPathPrefix/events/availability';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final newAvailability = data.cast<Map<String, dynamic>>();

        // Only update if data has actually changed
        if (!_listsEqual(_availability, newAvailability)) {
          _availability = newAvailability;
          _lastAvailabilityFetch = DateTime.now();
          await _cacheAvailability(_availability);

          if (!silent) {
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching availability: $e');
    }
  }

  /// Decode provider:sub from a JWT without verifying signature
  String? _decodeUserKeyFromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(_normalizeBase64(parts[1])));
      final jsonMap = json.decode(payload) as Map<String, dynamic>;
      final provider = (jsonMap['provider'] ?? 'google').toString();
      final sub = jsonMap['sub']?.toString();
      if (sub == null || sub.isEmpty) return null;
      return '$provider:$sub';
    } catch (_) {
      return null;
    }
  }

  String _normalizeBase64(String input) {
    final pad = input.length % 4;
    if (pad == 2) {
      return '$input'
          '==';
    }
    if (pad == 3) {
      return '$input'
          '=';
    }
    if (pad == 1) {
      return '$input'
          '==='; // unlikely but safe
    }
    return input;
  }

  /// Apply audience visibility rules client-side
  /// - If event.audience_user_keys is empty or missing: everyone sees all roles
  /// - If non-empty: show roles only if current userKey is listed, or role.visible_for_all is true
  List<Map<String, dynamic>> _filterEventsForAudience(
    List<Map<String, dynamic>> events,
    String? userKey,
  ) {
    return events.map((evt) {
      final roles = (evt['roles'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final audience = (evt['audience_user_keys'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (audience.isEmpty) {
        return {...evt, 'roles': roles};
      }
      final filteredRoles = roles.where((r) {
        final visibleAll =
            (r['visible_for_all'] == true) || (r['visibleForAll'] == true);
        if (visibleAll) return true;
        if (userKey == null) return false;
        return audience.contains(userKey);
      }).toList();
      return {...evt, 'roles': filteredRoles};
    }).toList();
  }

  /// Smart refresh - only fetches if data is stale
  Future<void> refreshIfNeeded() async {
    if (!isDataFresh) {
      await _fetchEvents();
    }
    if (!isAvailabilityFresh) {
      await _fetchAvailability();
    }
  }

  /// Manual refresh - always fetches fresh data (for pull-to-refresh)
  Future<void> forceRefresh() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      await Future.wait([_fetchEvents(), _fetchAvailability()]);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Background refresh - silent fetch to keep data fresh
  void _startBackgroundRefresh() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = Timer.periodic(
      Duration(minutes: _backgroundRefreshMinutes),
      (_) async {
        if (!isDataFresh) {
          await _fetchEvents(silent: true);
        }
        if (!isAvailabilityFresh) {
          await _fetchAvailability(silent: true);
        }
        // Notify listeners only once if any data changed
        notifyListeners();
      },
    );
  }

  /// Initial load - loads cached data first, then fetches if needed
  Future<void> loadInitialData() async {
    // If we have cached data, show it immediately
    if (_events.isNotEmpty) {
      notifyListeners();
    }

    // Then refresh if needed
    await refreshIfNeeded();
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await Future.wait([
      _storage.delete(key: _eventsStorageKey),
      _storage.delete(key: _lastFetchKey),
      _storage.delete(key: _availabilityStorageKey),
      _storage.delete(key: _lastAvailabilityFetchKey),
      _storage.delete(key: 'last_sync_events'),
    ]);

    _events.clear();
    _availability.clear();
    _lastFetch = null;
    _lastAvailabilityFetch = null;
    notifyListeners();
  }

  /// Force full sync on next fetch (clears delta sync timestamp)
  /// Call this after creating, updating, or deleting events
  Future<void> invalidateEventsCache() async {
    await _storage.delete(key: 'last_sync_events');
    debugPrint('Events cache invalidated - next fetch will be full sync');
  }

  /// Utility method to compare two lists for equality
  bool _listsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toString() != b[i].toString()) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    super.dispose();
  }

  /// Get time since last refresh in a human-readable format
  String getLastRefreshTime() {
    if (_lastFetch == null) return 'Never';

    final now = DateTime.now();
    final diff = now.difference(_lastFetch!);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
