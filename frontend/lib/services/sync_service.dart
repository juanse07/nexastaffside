import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_service.dart';
import '../auth_service.dart';
import '../models/pending_clock_action.dart';

/// Background sync callback for Workmanager
/// IMPORTANT: This runs in a separate isolate, so it can't access app state
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('[SyncService] Background task started: $task');

      // Initialize Hive in background isolate
      await OfflineService.initialize();

      // Run sync
      final syncedCount = await SyncService.syncPendingActions();

      print('[SyncService] Background sync completed: $syncedCount actions synced');
      return true;
    } catch (e) {
      print('[SyncService] Background sync failed: $e');
      return false;
    }
  });
}

class SyncService {
  static const String _syncTaskName = 'com.nexa.staff.sync';
  static const String _uniqueName = 'nexa_periodic_sync';

  static bool _isInitialized = false;
  static StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  static final _syncController = StreamController<int>.broadcast();

  /// Stream of sync events (emits count of synced actions)
  static Stream<int> get syncStream => _syncController.stream;

  /// Initialize SyncService and Workmanager
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Workmanager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );

      // Register periodic sync task (runs every 15 minutes)
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _syncTaskName,
        frequency: const Duration(minutes: 15),
      );

      // Listen for network connectivity changes
      _startConnectivityListener();

      _isInitialized = true;
      print('[SyncService] Initialized successfully');
    } catch (e) {
      print('[SyncService] Initialization failed: $e');
      rethrow;
    }
  }

  /// Start listening for network connectivity changes
  static void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        if (result != ConnectivityResult.none) {
          print('[SyncService] Network connected, triggering sync...');
          await syncPendingActions();
        }
      },
    );
  }

  /// Check if network is available
  static Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('[SyncService] Failed to check connectivity: $e');
      return false;
    }
  }

  /// Manually trigger sync of pending actions
  static Future<int> syncPendingActions() async {
    try {
      // Check network connectivity
      if (!await isOnline()) {
        print('[SyncService] No network connection, skipping sync');
        return 0;
      }

      // Get pending actions
      final pendingActions = await OfflineService.getPendingActions();
      if (pendingActions.isEmpty) {
        print('[SyncService] No pending actions to sync');
        return 0;
      }

      print('[SyncService] Syncing ${pendingActions.length} pending actions...');

      int syncedCount = 0;

      for (final action in pendingActions) {
        try {
          // Check if retry should be attempted (exponential backoff)
          if (!_shouldRetry(action)) {
            print('[SyncService] Skipping action ${action.id} (backoff in effect)');
            continue;
          }

          // Update status to 'syncing'
          await OfflineService.updateActionStatus(action.id, 'syncing');

          // Attempt to sync based on action type
          bool success = false;
          if (action.action == 'clock-in') {
            success = await _syncClockIn(action);
          } else if (action.action == 'clock-out') {
            success = await _syncClockOut(action);
          }

          if (success) {
            // Remove action from queue
            await OfflineService.removeAction(action.id);
            syncedCount++;
            print('[SyncService] ✓ Synced action: ${action.id}');
          } else {
            // Mark as failed and increment retry count
            await OfflineService.updateActionStatus(
              action.id,
              'failed',
              errorMessage: 'Sync failed',
            );
            await OfflineService.incrementRetryCount(action.id);
          }
        } catch (e) {
          print('[SyncService] Error syncing action ${action.id}: $e');
          await OfflineService.updateActionStatus(
            action.id,
            'failed',
            errorMessage: e.toString(),
          );
          await OfflineService.incrementRetryCount(action.id);
        }
      }

      print('[SyncService] Sync completed: $syncedCount/${pendingActions.length} actions synced');

      // Emit sync event
      _syncController.add(syncedCount);

      return syncedCount;
    } catch (e) {
      print('[SyncService] Sync failed: $e');
      return 0;
    }
  }

  /// Sync clock-in action
  static Future<bool> _syncClockIn(PendingClockAction action) async {
    try {
      final response = await AuthService.clockIn(eventId: action.eventId);
      return response != null;
    } catch (e) {
      print('[SyncService] Clock-in sync failed: $e');
      return false;
    }
  }

  /// Sync clock-out action
  static Future<bool> _syncClockOut(PendingClockAction action) async {
    try {
      final response = await AuthService.clockOut(eventId: action.eventId);
      return response != null;
    } catch (e) {
      print('[SyncService] Clock-out sync failed: $e');
      return false;
    }
  }

  /// Determine if action should be retried (exponential backoff)
  static bool _shouldRetry(PendingClockAction action) {
    if (action.status == 'pending') return true;
    if (action.lastRetryAt == null) return true;

    // Exponential backoff: 1min, 2min, 4min, 8min, 16min, then cap at 30min
    final backoffMinutes = action.retryCount == 0
      ? 0
      : (1 << (action.retryCount - 1)).clamp(1, 30);

    final nextRetryTime = action.lastRetryAt!.add(Duration(minutes: backoffMinutes));
    final canRetry = DateTime.now().isAfter(nextRetryTime);

    if (!canRetry) {
      final remaining = nextRetryTime.difference(DateTime.now());
      print('[SyncService] Action ${action.id} backoff: ${remaining.inMinutes}min remaining');
    }

    return canRetry;
  }

  /// Cancel all background tasks
  static Future<void> cancelAllTasks() async {
    try {
      await Workmanager().cancelAll();
      print('[SyncService] Cancelled all background tasks');
    } catch (e) {
      print('[SyncService] Failed to cancel tasks: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _syncController.close();
    _isInitialized = false;
  }
}
