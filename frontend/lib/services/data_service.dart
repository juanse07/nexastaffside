import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../auth_service.dart';
import 'chat_service.dart';

/// Enhanced data service with smart caching and efficient refresh mechanisms
class DataService extends ChangeNotifier {
  static const String _eventsStorageKey = 'cached_available';
  static const String _lastFetchKey = 'last_fetch_timestamp';
  static const String _availabilityStorageKey = 'cached_availability';
  static const String _lastAvailabilityFetchKey = 'last_availability_fetch';
  static const String _shiftsStorageKey = 'cached_shifts';
  static const String _lastShiftsFetchKey = 'last_shifts_fetch_timestamp';
  static const String _myShiftsStorageKey = 'cached_my_shifts';
  static const String _lastMyShiftsFetchKey = 'last_my_shifts_fetch_timestamp';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Cache duration in minutes - adjust based on your needs
  static const int _cacheExpiryMinutes = 5;
  static const int _backgroundRefreshMinutes = 2;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _availability = [];
  List<Map<String, dynamic>> _eventsRaw = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _myShifts = [];
  List<Map<String, dynamic>> _myShiftsRaw = [];
  DateTime? _lastMyShiftsFetch;
  List<Map<String, dynamic>> _myTeams = [];
  List<Map<String, dynamic>> _pendingInvites = [];
  final Set<String> _teamIds = <String>{};
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _teamsLoaded = false;
  String? _lastError;
  DateTime? _lastFetch;
  DateTime? _lastAvailabilityFetch;
  DateTime? _lastShiftsFetch;
  Timer? _backgroundRefreshTimer;
  io.Socket? _socket;
  bool _connectingSocket = false;
  final StreamController<Map<String, dynamic>> _eventChatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  List<Map<String, dynamic>> get availability =>
      List.unmodifiable(_availability);
  List<Map<String, dynamic>> get shifts => List.unmodifiable(_shifts);
  List<Map<String, dynamic>> get myShifts => List.unmodifiable(_myShifts);
  List<Map<String, dynamic>> get teams => List.unmodifiable(_myTeams);
  List<Map<String, dynamic>> get pendingInvites =>
      List.unmodifiable(_pendingInvites);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get teamsLoaded => _teamsLoaded;
  bool get hasTeams => _myTeams.isNotEmpty;
  String? get lastError => _lastError;
  DateTime? get lastFetch => _lastFetch;
  DateTime? get lastShiftsFetch => _lastShiftsFetch;
  bool get hasData => _events.isNotEmpty;
  bool get hasShiftsData => _shifts.isNotEmpty;
  bool get hasMyShiftsData => _myShifts.isNotEmpty;
  DateTime? get lastMyShiftsFetch => _lastMyShiftsFetch;

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

  /// Returns true if response is 401, triggering forced logout.
  bool _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint('🔒 401 Unauthorized detected - triggering forced logout');
      AuthService.forceLogout();
      return true;
    }
    return false;
  }

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    debugPrint('📱 DataService initializing...');
    await _loadCachedData();
    debugPrint('📦 Loaded ${_events.length} events from cache');
    _startBackgroundRefresh();
    // Always fetch fresh data on startup to ensure sync with server
    // This prevents showing stale cached data when events were deleted
    debugPrint('🌐 Fetching fresh data from server...');
    await Future.wait([
      _fetchAvailable(silent: true, forceFullSync: true),
      _fetchMyShifts(silent: true, forceFullSync: true),
      _fetchAvailability(silent: true),
      _fetchMyTeams(silent: true),
      _fetchMyInvites(silent: true),
    ]);
    notifyListeners();
    debugPrint('✅ DataService initialized with ${_events.length} events');
    unawaited(_ensureSocketConnected());
  }

  /// Safely read from storage with error handling
  Future<String?> _safeStorageRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Error reading from secure storage (key: $key): $e');
      // Clear corrupted storage entry
      await _storage.delete(key: key);
      return null;
    }
  }

  /// Safely write to storage with error handling and retry
  Future<void> _safeStorageWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error writing to secure storage (key: $key): $e');
      // Try to clear all storage and retry once
      try {
        await _storage.deleteAll();
        await _storage.write(key: key, value: value);
        debugPrint('Successfully wrote to storage after clearing');
      } catch (retryError) {
        debugPrint(
          'Failed to write to storage even after clearing: $retryError',
        );
        // Don't rethrow - continue operation even if storage fails
      }
    }
  }

  /// Load cached data from secure storage
  Future<void> _loadCachedData() async {
    try {
      // Load cached events
      final cachedEvents = await _safeStorageRead(_eventsStorageKey);
      if (cachedEvents != null) {
        final data = json.decode(cachedEvents) as List<dynamic>;
        _events = data.cast<Map<String, dynamic>>();
        _eventsRaw = List<Map<String, dynamic>>.from(_events);
      }

      // Load last fetch timestamp
      final lastFetchStr = await _safeStorageRead(_lastFetchKey);
      if (lastFetchStr != null) {
        _lastFetch = DateTime.tryParse(lastFetchStr);
      }

      // Load cached availability
      final cachedAvailability = await _safeStorageRead(
        _availabilityStorageKey,
      );
      if (cachedAvailability != null) {
        final data = json.decode(cachedAvailability) as List<dynamic>;
        _availability = data.cast<Map<String, dynamic>>();
      }

      // Load last availability fetch timestamp
      final lastAvailabilityStr = await _safeStorageRead(
        _lastAvailabilityFetchKey,
      );
      if (lastAvailabilityStr != null) {
        _lastAvailabilityFetch = DateTime.tryParse(lastAvailabilityStr);
      }

      // Load cached shifts
      final cachedShifts = await _safeStorageRead(_shiftsStorageKey);
      if (cachedShifts != null) {
        final data = json.decode(cachedShifts) as List<dynamic>;
        _shifts = data.cast<Map<String, dynamic>>();
      }

      // Load last shifts fetch timestamp
      final lastShiftsStr = await _safeStorageRead(_lastShiftsFetchKey);
      if (lastShiftsStr != null) {
        _lastShiftsFetch = DateTime.tryParse(lastShiftsStr);
      }

      // Load cached my-shifts
      final cachedMyShifts = await _safeStorageRead(_myShiftsStorageKey);
      if (cachedMyShifts != null) {
        final data = json.decode(cachedMyShifts) as List<dynamic>;
        _myShifts = data.cast<Map<String, dynamic>>();
        _myShiftsRaw = List<Map<String, dynamic>>.from(_myShifts);
      }

      // Load last my-shifts fetch timestamp
      final lastMyShiftsStr = await _safeStorageRead(_lastMyShiftsFetchKey);
      if (lastMyShiftsStr != null) {
        _lastMyShiftsFetch = DateTime.tryParse(lastMyShiftsStr);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  /// Cache data to secure storage
  Future<void> _cacheEvents(List<Map<String, dynamic>> events) async {
    try {
      await _safeStorageWrite(_eventsStorageKey, json.encode(events));
      await _safeStorageWrite(_lastFetchKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error caching events: $e');
    }
  }

  /// Cache shifts data to secure storage
  Future<void> _cacheShifts(List<Map<String, dynamic>> shifts) async {
    try {
      await _safeStorageWrite(_shiftsStorageKey, json.encode(shifts));
      await _safeStorageWrite(_lastShiftsFetchKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error caching shifts: $e');
    }
  }

  /// Cache my-shifts data to secure storage
  Future<void> _cacheMyShifts(List<Map<String, dynamic>> myShifts) async {
    try {
      await _safeStorageWrite(_myShiftsStorageKey, json.encode(myShifts));
      await _safeStorageWrite(_lastMyShiftsFetchKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error caching my-shifts: $e');
    }
  }

  /// Fetch events the user has accepted from /events/my-shifts
  Future<void> _fetchMyShifts({
    bool silent = false,
    bool forceFullSync = false,
  }) async {
    try {
      // Build URL with delta sync support
      String? lastSyncTimestamp;
      if (forceFullSync) {
        await _storage.delete(key: 'last_sync_my_shifts');
        lastSyncTimestamp = null;
      } else {
        lastSyncTimestamp = await _safeStorageRead('last_sync_my_shifts');
      }
      final uri = Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/my-shifts');
      final uriWithParams = lastSyncTimestamp != null
          ? uri.replace(queryParameters: {'lastSync': lastSyncTimestamp})
          : uri;

      final token = await _safeStorageRead('auth_jwt');
      if (token == null) return;
      final headers = <String, String>{'Authorization': 'Bearer $token'};

      debugPrint('🌍 Fetching my-shifts from ${uriWithParams.toString()} (forceFullSync=$forceFullSync)');
      final response = await http.get(uriWithParams, headers: headers);
      debugPrint('📥 My-shifts response status: ${response.statusCode}');

      if (_checkUnauthorized(response)) return;

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> eventsData;
        String? serverTimestamp;
        bool isDeltaSync = false;

        if (responseData is Map<String, dynamic>) {
          eventsData = (responseData['events'] ?? []) as List<dynamic>;
          serverTimestamp = responseData['serverTimestamp'] as String?;
          isDeltaSync = responseData['deltaSync'] == true;
        } else if (responseData is List) {
          eventsData = responseData;
          serverTimestamp = DateTime.now().toIso8601String();
        } else {
          throw Exception('Unexpected response format');
        }

        final updatedEvents = eventsData.cast<Map<String, dynamic>>();

        if (isDeltaSync && lastSyncTimestamp != null) {
          debugPrint('🔄 My-shifts delta sync: ${updatedEvents.length} changes');
          _myShiftsRaw = _mergeEvents(_myShiftsRaw, updatedEvents);
        } else {
          debugPrint('🔄 My-shifts full sync: ${updatedEvents.length} events');
          _myShiftsRaw = updatedEvents;
        }

        // No audience filtering needed — server already filtered by accepted_staff
        _myShifts = List<Map<String, dynamic>>.from(_myShiftsRaw);
        _lastMyShiftsFetch = DateTime.now();
        await _cacheMyShifts(_myShifts);

        if (serverTimestamp != null) {
          await _safeStorageWrite('last_sync_my_shifts', serverTimestamp);
        }

        if (!silent) {
          notifyListeners();
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to fetch my-shifts: $e');
    }
  }

  /// Cache availability data to secure storage
  Future<void> _cacheAvailability(
    List<Map<String, dynamic>> availability,
  ) async {
    try {
      await _safeStorageWrite(
        _availabilityStorageKey,
        json.encode(availability),
      );
      await _safeStorageWrite(
        _lastAvailabilityFetchKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error caching availability: $e');
    }
  }

  /// Fetch available events from server (future, non-accepted, non-draft)
  /// Server handles all visibility/acceptance/date filtering via /events/available
  Future<void> _fetchAvailable({
    bool silent = false,
    bool forceFullSync = false,
  }) async {
    if (!silent) {
      _isLoading = true;
      _lastError = null;
      notifyListeners();
    }

    try {
      // Build URL with delta sync support
      String? lastSyncTimestamp;
      if (forceFullSync) {
        await _storage.delete(key: 'last_sync_available');
        lastSyncTimestamp = null;
      } else {
        lastSyncTimestamp = await _safeStorageRead('last_sync_available');
      }
      final uri = Uri.parse('$_apiBaseUrl$_apiPathPrefix/events/available');
      final uriWithParams = lastSyncTimestamp != null
          ? uri.replace(queryParameters: {'lastSync': lastSyncTimestamp})
          : uri;

      final token = await _safeStorageRead('auth_jwt');
      final headers = <String, String>{};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      debugPrint(
        '🌍 Fetching available events from ${uriWithParams.toString()} (forceFullSync=$forceFullSync)',
      );
      final response = await http.get(uriWithParams, headers: headers);
      debugPrint('📥 Available events response status: ${response.statusCode}');

      if (_checkUnauthorized(response)) return;

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle both legacy (List) and new delta sync (Map) response formats
        List<dynamic> eventsData;
        String? serverTimestamp;
        bool isDeltaSync = false;
        Set<String> removedEventIds = {};

        if (responseData is List) {
          eventsData = responseData;
          serverTimestamp = DateTime.now().toIso8601String();
        } else if (responseData is Map<String, dynamic>) {
          eventsData = (responseData['events'] ?? []) as List<dynamic>;
          serverTimestamp = responseData['serverTimestamp'] as String?;
          isDeltaSync = responseData['deltaSync'] == true;
          removedEventIds = _extractRemovedEventIds(responseData);
        } else {
          throw Exception('Unexpected response format');
        }

        final updatedEvents = eventsData.cast<Map<String, dynamic>>();

        // Delta sync: merge changes with existing events
        if (isDeltaSync && lastSyncTimestamp != null) {
          debugPrint('🔄 Available delta sync: ${updatedEvents.length} changes received');
          _eventsRaw = _mergeEvents(
            _eventsRaw,
            updatedEvents,
            removedEventIds: removedEventIds,
          );
        } else {
          final fullNote = forceFullSync ? ' (forced)' : '';
          debugPrint(
            '🔄 Available full sync$fullNote: ${updatedEvents.length} events received (replacing ${_eventsRaw.length} cached)',
          );
          _eventsRaw = updatedEvents;
        }

        // No client-side filtering needed — server already filtered
        _events = List<Map<String, dynamic>>.from(_eventsRaw);
        debugPrint('[DATA_SERVICE] Available events: ${_events.length}');

        unawaited(_ensureSocketConnected());

        _lastFetch = DateTime.now();
        await _cacheEvents(_events);

        // Save server timestamp for next delta sync
        if (serverTimestamp != null) {
          await _safeStorageWrite('last_sync_available', serverTimestamp);
        }

        notifyListeners();
        _lastError = null;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _lastError = 'Failed to fetch available events: $e';
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
    List<Map<String, dynamic>> changes, {
    Set<String> removedEventIds = const <String>{},
  }) {
    final Map<String, Map<String, dynamic>> eventMap = {};
    for (final event in existing) {
      final id = _extractEventId(event);
      if (id != null) {
        eventMap[id] = Map<String, dynamic>.from(event);
      }
    }

    for (final change in changes) {
      final id = _extractEventId(change);
      if (id == null) continue;

      if (removedEventIds.contains(id) || _isEventMarkedDeleted(change)) {
        eventMap.remove(id);
        continue;
      }

      final sanitized = Map<String, dynamic>.from(change);
      sanitized['id'] = id;
      sanitized.remove('_id');
      eventMap[id] = sanitized;
    }

    for (final id in removedEventIds) {
      eventMap.remove(id);
    }

    eventMap.removeWhere((_, event) => _isEventMarkedDeleted(event));

    return eventMap.values.toList();
  }

  Future<void> _ensureSocketConnected() async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) return;
    final userKey = _decodeUserKeyFromToken(token);
    if (userKey == null) return;

    if (_socket != null) {
      _socket!.emit('register', {
        'userKey': userKey,
        'teamIds': _teamIds.toList(),
      });
      if (_teamIds.isNotEmpty) {
        _socket!.emit('joinTeams', _teamIds.toList());
      }
      return;
    }
    if (_connectingSocket) return;
    _connectingSocket = true;
    try {
      final uri = Uri.parse(_apiBaseUrl);
      final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
      final host = uri.host.isNotEmpty ? uri.host : uri.path;
      final port = uri.hasPort ? ':${uri.port}' : '';
      final origin = '$scheme://$host$port';

      final options = io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({
            'token': token,
            'userKey': userKey,
            'teamIds': _teamIds.toList(),
          })
          .disableAutoConnect()
          .build();

      final socket = io.io(origin, options);

      void refreshTeams() {
        unawaited(_fetchMyTeams(silent: true));
      }

      void refreshInvites() {
        unawaited(_fetchMyInvites(silent: true));
      }

      void refreshEvents({bool force = false}) {
        // force=true: Manual pull-to-refresh (full sync)
        // force=false: Socket event (use delta sync if available)
        unawaited(_fetchAvailable(silent: true, forceFullSync: force));
        unawaited(_fetchMyShifts(silent: true, forceFullSync: force));
      }

      // Real-time event removal handlers
      void _handleEventFulfilled(dynamic data) {
        if (data == null || data is! Map<String, dynamic>) return;
        final eventId = data['eventId']?.toString();
        if (eventId == null) return;

        // Remove from Available events (staff can no longer accept)
        _events.removeWhere((e) => (e['id'] ?? e['_id']).toString() == eventId);
        _eventsRaw.removeWhere((e) => (e['id'] ?? e['_id']).toString() == eventId);

        notifyListeners();
        debugPrint('✅ [REAL-TIME] Shift $eventId is now full - removed from Available');
      }

      void _handleEventDeleted(dynamic data) {
        if (data == null || data is! Map<String, dynamic>) return;
        final eventId = data['id']?.toString();
        if (eventId == null) return;

        _events.removeWhere((e) => (e['id'] ?? e['_id']).toString() == eventId);
        _eventsRaw.removeWhere((e) => (e['id'] ?? e['_id']).toString() == eventId);

        notifyListeners();
        debugPrint('🗑️ [REAL-TIME] Shift $eventId deleted - removed from Available');
      }

      void _handleEventCanceled(dynamic data) {
        // Same behavior as deleted for staff perspective
        _handleEventDeleted(data);
        debugPrint('❌ [REAL-TIME] Shift canceled - removed from Available');
      }

      socket.onConnect((_) {
        socket.emit('register', {
          'userKey': userKey,
          'teamIds': _teamIds.toList(),
        });
        if (_teamIds.isNotEmpty) {
          socket.emit('joinTeams', _teamIds.toList());
        }
      });

      socket.on('team:memberAdded', (_) => refreshTeams());
      socket.on('team:memberRemoved', (_) => refreshTeams());
      socket.on('team:created', (_) => refreshTeams());
      socket.on('team:deleted', (_) => refreshTeams());
      socket.on('team:updated', (_) => refreshTeams());

      socket.on('team:invitesCreated', (_) => refreshInvites());
      socket.on('team:inviteReceived', (_) => refreshInvites());
      socket.on('team:inviteCancelled', (_) => refreshInvites());
      socket.on('team:inviteAccepted', (_) => refreshTeams());
      socket.on('team:inviteDeclined', (_) => refreshInvites());

      socket.on('event:created', (_) => refreshEvents());
      socket.on('event:updated', (_) => refreshEvents());

      // Real-time shift removal when full, deleted, or canceled
      socket.on('event:fulfilled', (data) => _handleEventFulfilled(data));
      socket.on('event:deleted', (data) => _handleEventDeleted(data));
      socket.on('event:canceled', (data) => _handleEventCanceled(data));

      // Chat message listener
      socket.on('chat:message', (data) {
        debugPrint('[SOCKET] Received chat:message event: $data');
        if (data != null && data is Map<String, dynamic>) {
          // Forward to ChatService
          try {
            final chatService = ChatService();
            chatService.handleIncomingMessage(data);
          } catch (e) {
            debugPrint('[SOCKET] Error handling chat message: $e');
          }

          // If this is an event invitation, refresh events so it appears in Available tab
          final messageType = data['messageType']?.toString();
          if (messageType == 'eventInvitation') {
            debugPrint('[SOCKET] Event invitation received - refreshing events list');
            // Use brief delay for smoother UX (avoids rapid API calls)
            Future.delayed(const Duration(milliseconds: 500), () {
              _fetchAvailable(silent: true, forceFullSync: true);
              _fetchMyShifts(silent: true, forceFullSync: true);
            });
          }
        }
      });

      // Event team chat message listener
      socket.on('event_chat:message', (data) {
        debugPrint('[SOCKET] Received event_chat:message event: $data');
        if (data != null && data is Map<String, dynamic>) {
          // Forward to EventTeamChatService via stream
          _eventChatMessageController.add(data);
        }
      });

      socket.connect();
      _socket = socket;
    } finally {
      _connectingSocket = false;
    }
  }

  Set<String> _extractRemovedEventIds(Map<String, dynamic> payload) {
    final result = <String>{};

    void addId(dynamic raw) {
      if (raw == null) return;
      final id = raw.toString();
      if (id.isNotEmpty) {
        result.add(id);
      }
    }

    const candidateKeys = [
      'removedEventIds',
      'deletedEventIds',
      'removedIds',
      'deletedIds',
      'tombstoneIds',
    ];

    for (final key in candidateKeys) {
      final value = payload[key];
      if (value is List) {
        for (final item in value) {
          addId(item);
        }
      } else if (value != null && key == 'removedEventIds' && value is String) {
        addId(value);
      }
    }

    final deletedEntries = payload['deletedEvents'] ?? payload['removedEvents'];
    if (deletedEntries is List) {
      for (final entry in deletedEntries) {
        if (entry is Map<String, dynamic>) {
          final id = entry['_id'] ?? entry['id'];
          if (id != null) {
            addId(id);
          }
        } else {
          addId(entry);
        }
      }
    } else if (deletedEntries is Map<String, dynamic>) {
      addId(deletedEntries['_id'] ?? deletedEntries['id']);
    }

    final tombstones = payload['tombstones'];
    if (tombstones is List) {
      for (final entry in tombstones) {
        if (entry is Map<String, dynamic>) {
          final id = entry['_id'] ?? entry['id'];
          final deleted =
              entry['deleted'] == true ||
              entry['isDeleted'] == true ||
              entry['tombstone'] == true ||
              entry['__tombstone__'] == true ||
              entry.containsKey('deletedAt') ||
              entry.containsKey('deleted_at');
          if (id != null && deleted) {
            addId(id);
          }
        } else {
          addId(entry);
        }
      }
    }

    return result;
  }

  String? _extractEventId(Map<String, dynamic> event) {
    final id = event['id'] ?? event['_id'];
    if (id == null) return null;
    final idStr = id.toString();
    return idStr.isEmpty ? null : idStr;
  }

  bool _isEventMarkedDeleted(Map<String, dynamic> event) {
    bool isTruthy(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is DateTime) return true;
      final str = value.toString().trim().toLowerCase();
      if (str.isEmpty) return false;
      if (str == 'false' || str == '0' || str == 'null') return false;
      if (DateTime.tryParse(value.toString()) != null) return true;
      return true;
    }

    bool flagTrue(String key) => isTruthy(event[key]);

    final status = event['status']?.toString().toLowerCase();
    final tombstone =
        isTruthy(event['tombstone']) ||
        isTruthy(event['__tombstone__']) ||
        isTruthy(event['isTombstone']);
    final hasDeletedTimestamp =
        (event.containsKey('deletedAt') && event['deletedAt'] != null) ||
        (event.containsKey('deleted_at') && event['deleted_at'] != null);

    return flagTrue('deleted') ||
        flagTrue('_deleted') ||
        flagTrue('isDeleted') ||
        flagTrue('is_deleted') ||
        flagTrue('removed') ||
        flagTrue('isRemoved') ||
        tombstone ||
        hasDeletedTimestamp ||
        (status == 'deleted');
  }

  /// Fetch past events from server using existing events endpoint
  Future<void> _fetchShifts({bool silent = false}) async {
    try {
      final token = await _safeStorageRead('auth_jwt');
      if (token == null) return;

      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
      final apiPathPrefix = dotenv.env['API_PATH_PREFIX'] ?? '/api';
      final uri = Uri.parse('$baseUrl$apiPathPrefix/events');

      debugPrint('🔄 Fetching events for past events view from ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📥 Events response status: ${response.statusCode}');

      if (_checkUnauthorized(response)) return;

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final eventsData = responseData is List
          ? responseData.cast<Map<String, dynamic>>()
          : (responseData['events'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        debugPrint('🛰️ Received ${eventsData.length} events for past events filtering');

        _shifts = eventsData; // Store in _shifts for past events use
        _lastShiftsFetch = DateTime.now();
        await _cacheShifts(_shifts);

        debugPrint('✅ Successfully loaded ${_shifts.length} events for past view');

        if (!silent) {
          notifyListeners();
        }
      } else {
        debugPrint('❌ Failed to fetch events: ${response.statusCode} ${response.body}');
        if (!silent) {
          _lastError = 'Failed to fetch events: ${response.statusCode}';
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching events: $e');
      if (!silent) {
        _lastError = 'Error fetching events: $e';
        notifyListeners();
      }
    }
  }

  /// Public method to fetch shifts (for manual refresh)
  Future<void> fetchShifts({bool silent = false}) async {
    await _fetchShifts(silent: silent);
  }

  /// Fetch availability from server with JWT token
  Future<void> _fetchAvailability({bool silent = false}) async {
    try {
      final token = await _safeStorageRead('auth_jwt');
      if (token == null) return;

      final url = '$_apiBaseUrl$_apiPathPrefix/events/availability';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (_checkUnauthorized(response)) return;

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

  void _updateTeamIds() {
    _teamIds
      ..clear()
      ..addAll(
        _myTeams
            .map((team) => team['teamId']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      );
    unawaited(_ensureSocketConnected());
  }

  Future<void> _fetchMyTeams({bool silent = false}) async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) return;
    final userKey = _decodeUserKeyFromToken(token);
    final uri = Uri.parse('$_apiBaseUrl$_apiPathPrefix/teams/my');
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (userKey != null) headers['x-user-key'] = userKey;

    try {
      final response = await http.get(uri, headers: headers);
      if (_checkUnauthorized(response)) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final teamsRaw = decoded['teams'] as List? ?? const [];
        _myTeams = teamsRaw
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false);
        _teamsLoaded = true;
        _updateTeamIds();
        // Re-fetch available events since team membership affects visibility
        unawaited(_fetchAvailable(silent: true, forceFullSync: true));
        notifyListeners();
      } else {
        debugPrint(
          'Failed to fetch teams: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching teams: $e');
    }
  }

  Future<void> _fetchMyInvites({bool silent = false}) async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) return;
    final userKey = _decodeUserKeyFromToken(token);
    final uri = Uri.parse('$_apiBaseUrl$_apiPathPrefix/teams/my/invites');
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (userKey != null) headers['x-user-key'] = userKey;

    try {
      final response = await http.get(uri, headers: headers);
      if (_checkUnauthorized(response)) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final invitesRaw = decoded['invites'] as List? ?? const [];
        _pendingInvites = invitesRaw
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false);
        notifyListeners();
      } else {
        debugPrint(
          'Failed to fetch invites: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching invites: $e');
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

  // Client-side audience filtering removed — server handles all visibility
  // filtering via GET /events/available endpoint

  /// Smart refresh - only fetches if data is stale
  Future<void> refreshIfNeeded() async {
    if (!isDataFresh) {
      await _fetchAvailable();
    }
    if (!isAvailabilityFresh) {
      await _fetchAvailability();
    }
    await _fetchMyShifts(silent: true);
    await _fetchMyTeams(silent: true);
    await _fetchMyInvites(silent: true);
  }

  /// Manual refresh - always fetches fresh data (for pull-to-refresh)
  Future<void> forceRefresh() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      await Future.wait([
        _fetchAvailable(forceFullSync: true),
        _fetchMyShifts(forceFullSync: true),
        _fetchAvailability(),
        _fetchMyTeams(silent: true),
        _fetchMyInvites(silent: true),
      ]);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshTeamsAndInvites() async {
    await Future.wait([_fetchMyTeams(), _fetchMyInvites()]);
  }

  Future<void> acceptInvite(String inviteToken) async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final userKey = _decodeUserKeyFromToken(token);
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (userKey != null) headers['x-user-key'] = userKey;
    final uri = Uri.parse(
      '$_apiBaseUrl$_apiPathPrefix/invites/$inviteToken/accept',
    );

    final response = await http.post(uri, headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _fetchMyInvites(silent: true);
      await _fetchMyTeams(silent: true);
      await _fetchAvailable(silent: true, forceFullSync: true);
      await _fetchMyShifts(silent: true, forceFullSync: true);
      notifyListeners();
    } else {
      throw Exception('Failed to accept invite (${response.statusCode})');
    }
  }

  Future<void> declineInvite(String inviteToken) async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final userKey = _decodeUserKeyFromToken(token);
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (userKey != null) headers['x-user-key'] = userKey;
    final uri = Uri.parse(
      '$_apiBaseUrl$_apiPathPrefix/invites/$inviteToken/decline',
    );

    final response = await http.post(uri, headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _fetchMyInvites(silent: true);
      notifyListeners();
    } else {
      throw Exception('Failed to decline invite (${response.statusCode})');
    }
  }

  /// Validate an invite code and return team information
  Future<Map<String, dynamic>> validateInviteCode(String code) async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final userKey = _decodeUserKeyFromToken(token);
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (userKey != null) headers['x-user-key'] = userKey;

    final uri = Uri.parse(
      '$_apiBaseUrl$_apiPathPrefix/invites/validate/$code',
    );

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } else if (response.statusCode == 404) {
      throw Exception('Invalid or expired invite code');
    } else if (response.statusCode == 400) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final error = data['error'] ?? 'Invalid invite code';
      throw Exception(error);
    } else {
      throw Exception('Failed to validate invite code (${response.statusCode})');
    }
  }

  /// Redeem an invite code to join a team
  Future<void> redeemInviteCode(String code) async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final userKey = _decodeUserKeyFromToken(token);
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    if (userKey != null) headers['x-user-key'] = userKey;

    final uri = Uri.parse(
      '$_apiBaseUrl$_apiPathPrefix/invites/redeem',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode({'shortCode': code}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Refresh teams and events after successful redemption
      await _fetchMyTeams(silent: true);
      await _fetchAvailable(silent: true, forceFullSync: true);
      notifyListeners();
    } else if (response.statusCode == 404) {
      throw Exception('Invalid or expired invite code');
    } else if (response.statusCode == 400 || response.statusCode == 409 || response.statusCode == 410) {
      // Parse error message from backend (400 = validation, 409 = conflict/already member, 410 = expired/max uses)
      try {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final error = data['message'] ?? data['error'] ?? 'Failed to join team';
        throw Exception(error);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Failed to join team (${response.statusCode})');
      }
      throw Exception('Failed to join team (${response.statusCode})');
    }
  }

  /// Background refresh - silent fetch to keep data fresh
  void _startBackgroundRefresh() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = Timer.periodic(
      Duration(minutes: _backgroundRefreshMinutes),
      (_) async {
        if (!isDataFresh) {
          await _fetchAvailable(silent: true);
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
      _storage.delete(key: 'last_sync_available'),
      _storage.delete(key: _myShiftsStorageKey),
      _storage.delete(key: _lastMyShiftsFetchKey),
      _storage.delete(key: 'last_sync_my_shifts'),
    ]);

    _events.clear();
    _availability.clear();
    _myShifts.clear();
    _myShiftsRaw.clear();
    _lastFetch = null;
    _lastAvailabilityFetch = null;
    _lastMyShiftsFetch = null;
    notifyListeners();
  }

  /// Force full sync on next fetch (clears delta sync timestamp)
  /// Call this after creating, updating, or deleting events
  Future<void> invalidateEventsCache() async {
    await _storage.delete(key: 'last_sync_available');
    debugPrint('🗑️  Events cache invalidated - next fetch will be full sync');
  }

  /// Invalidate availability cache so next access fetches fresh data
  /// Call after AI chat marks availability via tool
  Future<void> invalidateAvailabilityCache() async {
    _lastAvailabilityFetch = null;
    await _fetchAvailability();
    debugPrint('🗑️  Availability cache invalidated and refreshed');
  }

  /// Utility method to compare two lists for equality
  bool _listsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toString() != b[i].toString()) return false;
    }
    return true;
  }

  /// Event chat message stream
  Stream<Map<String, dynamic>> get eventChatMessageStream =>
      _eventChatMessageController.stream;

  /// Emit a socket event
  void emitSocketEvent(String event, dynamic data) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
      debugPrint('[SOCKET] Emitted $event: $data');
    } else {
      debugPrint('[SOCKET] Cannot emit $event - socket not connected');
    }
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _eventChatMessageController.close();
    _socket?.dispose();
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
