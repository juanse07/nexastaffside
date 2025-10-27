import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/pending_clock_action.dart';

class OfflineService {
  static const String _boxName = 'pendingActions';
  static const String _locationCacheName = 'locationCache';

  static Box<PendingClockAction>? _actionsBox;
  static Box<Map>? _locationCacheBox;

  /// Initialize Hive and open boxes
  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();

      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PendingClockActionAdapter());
      }

      // Open boxes
      _actionsBox = await Hive.openBox<PendingClockAction>(_boxName);
      _locationCacheBox = await Hive.openBox<Map>(_locationCacheName);

      print('[OfflineService] Initialized successfully');
    } catch (e) {
      print('[OfflineService] Initialization error: $e');
      rethrow;
    }
  }

  /// Add a pending clock action to the queue
  static Future<void> addPendingAction(PendingClockAction action) async {
    try {
      final box = _actionsBox ?? await Hive.openBox<PendingClockAction>(_boxName);
      await box.put(action.id, action);
      print('[OfflineService] Added pending action: ${action.id} (${action.action})');
    } catch (e) {
      print('[OfflineService] Failed to add pending action: $e');
      rethrow;
    }
  }

  /// Get all pending actions
  static Future<List<PendingClockAction>> getPendingActions() async {
    try {
      final box = _actionsBox ?? await Hive.openBox<PendingClockAction>(_boxName);
      return box.values.where((action) =>
        action.status == 'pending' || action.status == 'failed'
      ).toList();
    } catch (e) {
      print('[OfflineService] Failed to get pending actions: $e');
      return [];
    }
  }

  /// Get count of pending actions
  static Future<int> getPendingCount() async {
    try {
      final actions = await getPendingActions();
      return actions.length;
    } catch (e) {
      print('[OfflineService] Failed to get pending count: $e');
      return 0;
    }
  }

  /// Update action status
  static Future<void> updateActionStatus(
    String id,
    String status, {
    String? errorMessage,
  }) async {
    try {
      final box = _actionsBox ?? await Hive.openBox<PendingClockAction>(_boxName);
      final action = box.get(id);
      if (action != null) {
        action.status = status;
        action.errorMessage = errorMessage;
        action.lastRetryAt = DateTime.now();
        await action.save();
        print('[OfflineService] Updated action $id status to: $status');
      }
    } catch (e) {
      print('[OfflineService] Failed to update action status: $e');
    }
  }

  /// Increment retry count
  static Future<void> incrementRetryCount(String id) async {
    try {
      final box = _actionsBox ?? await Hive.openBox<PendingClockAction>(_boxName);
      final action = box.get(id);
      if (action != null) {
        action.retryCount += 1;
        action.lastRetryAt = DateTime.now();
        await action.save();
        print('[OfflineService] Incremented retry count for $id: ${action.retryCount}');
      }
    } catch (e) {
      print('[OfflineService] Failed to increment retry count: $e');
    }
  }

  /// Remove a completed action
  static Future<void> removeAction(String id) async {
    try {
      final box = _actionsBox ?? await Hive.openBox<PendingClockAction>(_boxName);
      await box.delete(id);
      print('[OfflineService] Removed action: $id');
    } catch (e) {
      print('[OfflineService] Failed to remove action: $e');
    }
  }

  /// Cache location for an event (used for offline clock-out)
  static Future<void> cacheLocation(String eventId, Position position) async {
    try {
      final box = _locationCacheBox ?? await Hive.openBox<Map>(_locationCacheName);
      await box.put(eventId, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
      });
      print('[OfflineService] Cached location for event: $eventId');
    } catch (e) {
      print('[OfflineService] Failed to cache location: $e');
    }
  }

  /// Get cached location for an event
  static Future<Map<String, dynamic>?> getCachedLocation(String eventId) async {
    try {
      final box = _locationCacheBox ?? await Hive.openBox<Map>(_locationCacheName);
      final cached = box.get(eventId);
      if (cached != null) {
        return Map<String, dynamic>.from(cached);
      }
      return null;
    } catch (e) {
      print('[OfflineService] Failed to get cached location: $e');
      return null;
    }
  }

  /// Remove cached location
  static Future<void> removeCachedLocation(String eventId) async {
    try {
      final box = _locationCacheBox ?? await Hive.openBox<Map>(_locationCacheName);
      await box.delete(eventId);
      print('[OfflineService] Removed cached location for: $eventId');
    } catch (e) {
      print('[OfflineService] Failed to remove cached location: $e');
    }
  }

  /// Clear all pending actions (use with caution)
  static Future<void> clearAllActions() async {
    try {
      final box = _actionsBox ?? await Hive.openBox<PendingClockAction>(_boxName);
      await box.clear();
      print('[OfflineService] Cleared all pending actions');
    } catch (e) {
      print('[OfflineService] Failed to clear actions: $e');
    }
  }

  /// Close all boxes
  static Future<void> close() async {
    try {
      await _actionsBox?.close();
      await _locationCacheBox?.close();
      print('[OfflineService] Closed all boxes');
    } catch (e) {
      print('[OfflineService] Failed to close boxes: $e');
    }
  }
}
