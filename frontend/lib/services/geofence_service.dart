import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth_service.dart';
import 'offline_service.dart';
import '../models/pending_clock_action.dart';

/// Service that manages geofencing for automatic clock-in functionality
///
/// This service:
/// - Monitors user location every minute when geofences are active
/// - Automatically triggers clock-in when BOTH conditions are met:
///   1. User is within 500m of event venue
///   2. Current time is 2 minutes or less before shift start time
/// - Handles offline queueing if network unavailable
/// - Shows notifications on successful auto clock-in
class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final List<_EventGeofence> _activeGeofences = [];
  final Set<String> _triggeredEvents = {}; // Track which events already auto-clocked
  final StreamController<String> _clockInEventController = StreamController<String>.broadcast();

  Timer? _locationCheckTimer;
  bool _isInitialized = false;
  bool _isMonitoring = false;

  static const double _geofenceRadius = 500.0; // meters
  static const Duration _locationCheckInterval = Duration(minutes: 1); // Check every minute for accuracy
  static const Duration _clockInWindowBefore = Duration(minutes: 2); // Can only clock in 2 min before shift

  /// Stream of event IDs that were auto-clocked-in
  Stream<String> get onAutoClockIn => _clockInEventController.stream;

  /// Initialize the geofence service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);

    // Request location permissions
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }

    _isInitialized = true;
    debugPrint('GeofenceService initialized');
  }

  /// Start monitoring geofences
  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isMonitoring) return;

    if (_activeGeofences.isNotEmpty) {
      _locationCheckTimer?.cancel();
      _locationCheckTimer = Timer.periodic(_locationCheckInterval, (_) => _checkLocation());
      _isMonitoring = true;
      // Do initial check immediately
      _checkLocation();
      debugPrint('Geofence monitoring started with ${_activeGeofences.length} geofences');
    }
  }

  /// Stop monitoring geofences
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _locationCheckTimer?.cancel();
    _locationCheckTimer = null;
    _isMonitoring = false;
    debugPrint('Geofence monitoring stopped');
  }

  /// Register geofences for accepted events
  ///
  /// Creates a geofence for each event that:
  /// - Has a venue address
  /// - User has accepted
  /// - Is not yet ended
  ///
  /// Auto clock-in will only trigger when:
  /// - User is within 500m of venue
  /// - Time is 2 minutes or less before shift start
  Future<void> registerEventGeofences(List<Map<String, dynamic>> events) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Clear existing geofences
    _activeGeofences.clear();

    final now = DateTime.now();

    for (final event in events) {
      try {
        final eventId = event['_id'] as String?;
        final venueAddress = event['venue_address']?.toString().trim();
        final startStr = event['start_time'] as String?;
        final endStr = event['end_time'] as String?;

        if (eventId == null || venueAddress == null || venueAddress.isEmpty) {
          continue;
        }

        if (startStr == null) continue;

        final startTime = DateTime.parse(startStr);
        final endTime = endStr != null ? DateTime.parse(endStr) : startTime.add(const Duration(hours: 12));

        // Only create geofences for events that haven't ended yet
        // Note: We don't check the 2-minute window here - that's checked during location monitoring
        if (now.isAfter(endTime)) {
          continue; // Event already ended
        }

        // Geocode venue address to get coordinates
        try {
          final locations = await locationFromAddress(venueAddress);
          if (locations.isEmpty) continue;

          final location = locations.first;

          // Create geofence
          final geofence = _EventGeofence(
            eventId: eventId,
            eventName: event['name']?.toString() ?? 'Event',
            latitude: location.latitude,
            longitude: location.longitude,
            radius: _geofenceRadius,
            startTime: startTime,
            endTime: endTime,
          );

          _activeGeofences.add(geofence);
          debugPrint('Registered geofence for event $eventId at ${location.latitude},${location.longitude}');
        } catch (e) {
          debugPrint('Failed to geocode address for event $eventId: $e');
        }
      } catch (e) {
        debugPrint('Error processing event for geofence: $e');
      }
    }

    // Save geofence state
    await _saveGeofenceState();

    // Restart monitoring with new geofences
    if (_activeGeofences.isNotEmpty) {
      await stopMonitoring();
      await startMonitoring();
    } else {
      await stopMonitoring();
    }
  }

  /// Remove a specific event geofence
  Future<void> removeEventGeofence(String eventId) async {
    _activeGeofences.removeWhere((g) => g.eventId == eventId);
    _triggeredEvents.remove(eventId);
    await _saveGeofenceState();

    // Restart monitoring
    if (_activeGeofences.isEmpty) {
      await stopMonitoring();
    } else {
      await stopMonitoring();
      await startMonitoring();
    }
  }

  /// Clear all geofences
  Future<void> clearAll() async {
    _activeGeofences.clear();
    _triggeredEvents.clear();
    await stopMonitoring();
    await _saveGeofenceState();
    debugPrint('All geofences cleared');
  }

  /// Periodic location check
  Future<void> _checkLocation() async {
    if (_activeGeofences.isEmpty) return;

    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      final now = DateTime.now();

      // Check each geofence
      for (final geofence in _activeGeofences) {
        // Skip if already triggered
        if (_triggeredEvents.contains(geofence.eventId)) {
          continue;
        }

        // Check if in time window (2 minutes before shift start to event end)
        final clockInStart = geofence.startTime.subtract(_clockInWindowBefore);
        if (now.isBefore(clockInStart) || now.isAfter(geofence.endTime)) {
          debugPrint('Event ${geofence.eventId} not in time window. Start: $clockInStart, Now: $now, End: ${geofence.endTime}');
          continue;
        }

        // Calculate distance
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          geofence.latitude,
          geofence.longitude,
        );

        // Check if within radius
        if (distance <= geofence.radius) {
          debugPrint('Entered geofence for event: ${geofence.eventId} (distance: ${distance}m)');
          await _handleGeofenceEnter(geofence.eventId, position);
          _triggeredEvents.add(geofence.eventId);
        }
      }
    } catch (e) {
      debugPrint('Error checking location: $e');
    }
  }

  /// Handle entering a geofence (event venue)
  Future<void> _handleGeofenceEnter(String eventId, Position position) async {
    debugPrint('Processing auto clock-in for event: $eventId');

    try {
      // Check if already clocked in
      final status = await _getAttendanceStatus(eventId);
      if (status == 'clocked_in' || status == 'completed') {
        debugPrint('Already clocked in to event: $eventId');
        return;
      }

      // Attempt automatic clock-in
      await _performAutoClockIn(eventId, position);

    } catch (e) {
      debugPrint('Error handling geofence enter: $e');
    }
  }

  /// Perform automatic clock-in
  Future<void> _performAutoClockIn(String eventId, Position position) async {
    try {
      // Check network connectivity
      bool isOnline;
      try {
        final result = await http.get(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 5));
        isOnline = result.statusCode == 200;
      } catch (_) {
        isOnline = false;
      }

      if (isOnline) {
        // Online: call API directly
        final success = await _callClockInAPI(eventId, position.latitude, position.longitude, 'live');
        if (success) {
          await _showAutoClockInNotification(eventId);
          _clockInEventController.add(eventId);
          debugPrint('Auto clock-in successful for event: $eventId');
        }
      } else {
        // Offline: queue for later sync
        await _queueOfflineClockIn(eventId, position.latitude, position.longitude);
        await _showAutoClockInNotification(eventId, offline: true);
        _clockInEventController.add(eventId);
        debugPrint('Auto clock-in queued offline for event: $eventId');
      }
    } catch (e) {
      debugPrint('Error performing auto clock-in: $e');
    }
  }

  /// Call clock-in API
  Future<bool> _callClockInAPI(String eventId, double latitude, double longitude, String locationSource) async {
    try {
      final result = await AuthService.clockIn(
        eventId: eventId,
        latitude: latitude,
        longitude: longitude,
        locationSource: locationSource,
      );
      return result != null;
    } catch (e) {
      debugPrint('Error calling clock-in API: $e');
      return false;
    }
  }

  /// Queue offline clock-in
  Future<void> _queueOfflineClockIn(String eventId, double latitude, double longitude) async {
    final action = PendingClockAction(
      id: '${eventId}_clockin_auto_${DateTime.now().millisecondsSinceEpoch}',
      action: 'clock-in',
      eventId: eventId,
      timestamp: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      locationSource: 'live',
      status: 'pending',
    );
    await OfflineService.addPendingAction(action);
  }

  /// Get attendance status for event
  Future<String?> _getAttendanceStatus(String eventId) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) return null;

      final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
      final url = Uri.parse('$apiBaseUrl/api/events/$eventId/attendance/me');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] as String?;
      }
      return 'not_started';
    } catch (e) {
      debugPrint('Error getting attendance status: $e');
      return null;
    }
  }

  /// Show auto clock-in notification
  Future<void> _showAutoClockInNotification(String eventId, {bool offline = false}) async {
    const androidDetails = AndroidNotificationDetails(
      'auto_clockin',
      'Auto Clock-in',
      channelDescription: 'Notifications for automatic clock-in events',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final message = offline
        ? 'Auto clocked in (will sync when online)'
        : 'Successfully auto clocked in';

    await _notifications.show(
      eventId.hashCode,
      'Auto Clock-in',
      message,
      details,
    );
  }

  /// Save geofence state to persistent storage
  Future<void> _saveGeofenceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final geofenceData = _activeGeofences.map((g) => {
        'id': g.eventId,
        'latitude': g.latitude,
        'longitude': g.longitude,
      }).toList();
      await prefs.setString('active_geofences', jsonEncode(geofenceData));
    } catch (e) {
      debugPrint('Error saving geofence state: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _locationCheckTimer?.cancel();
    _clockInEventController.close();
  }
}

/// Internal class representing an event geofence
class _EventGeofence {
  final String eventId;
  final String eventName;
  final double latitude;
  final double longitude;
  final double radius;
  final DateTime startTime;
  final DateTime endTime;

  _EventGeofence({
    required this.eventId,
    required this.eventName,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.startTime,
    required this.endTime,
  });
}
