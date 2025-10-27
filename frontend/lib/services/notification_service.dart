import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // OneSignal App ID for Staff app
  static const String _oneSignalAppId = 'b974a231-c50a-4c4b-9cb0-59c6e078643d';

  // API Base URL - Using production backend
  static const String _baseUrl = 'https://api.nexapymesoft.com';

  // Notification counts
  int _unreadChatCount = 0;
  int _unreadTaskCount = 0;
  int _unreadEventCount = 0;
  final _notificationCountController = StreamController<int>.broadcast();

  Stream<int> get notificationCountStream => _notificationCountController.stream;
  int get totalUnreadCount => _unreadChatCount + _unreadTaskCount + _unreadEventCount;

  /// Initialize OneSignal and local notifications
  Future<void> initialize() async {
    try {
      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Initialize OneSignal
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      OneSignal.initialize(_oneSignalAppId);

      // Request permission (iOS only, Android granted at install)
      if (Platform.isIOS) {
        final permission = await OneSignal.Notifications.requestPermission(true);
        print('OneSignal permission granted: $permission');
      }

      // Set up notification handlers
      _setupNotificationHandlers();

      // Get and register device token
      await _registerDevice();

      // Load notification preferences
      await _loadNotificationPreferences();

      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize NotificationService: $e');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationClick,
    );
  }

  /// Set up OneSignal notification handlers
  void _setupNotificationHandlers() {
    // Handle notification when received (app in foreground)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('Notification received in foreground: ${event.notification.title}');

      // Show local notification when app is in foreground
      _showLocalNotification(
        event.notification.title ?? 'New Notification',
        event.notification.body ?? '',
        event.notification.additionalData ?? {},
      );

      // Update badge count
      _updateBadgeCount(event.notification.additionalData);
    });

    // Handle notification click
    OneSignal.Notifications.addClickListener((event) {
      print('Notification clicked: ${event.notification.title}');
      _handleNotificationClick(event.notification.additionalData ?? {});
    });

    // Handle permission changes
    OneSignal.Notifications.addPermissionObserver((permission) {
      print('Permission changed: $permission');
      _secureStorage.write(key: 'notificationsEnabled', value: permission.toString());
    });
  }

  /// Register device with backend
  Future<void> _registerDevice() async {
    try {
      // IMPORTANT: Wait for OneSignal to fully initialize
      // Sometimes the subscription happens asynchronously
      await Future.delayed(const Duration(seconds: 2));

      // Get OneSignal Player ID
      final deviceState = await OneSignal.User.getOnesignalId();

      if (deviceState == null) {
        print('[NOTIF REG] No OneSignal Player ID available yet - retrying in 3s');
        // Retry after a delay
        await Future.delayed(const Duration(seconds: 3));
        final retryState = await OneSignal.User.getOnesignalId();
        if (retryState == null) {
          print('[NOTIF REG] Still no Player ID after retry - giving up');
          return;
        }
        print('[NOTIF REG] Got Player ID on retry: $retryState');
      }

      final playerId = deviceState ?? await OneSignal.User.getOnesignalId();
      if (playerId == null) return;

      // Check if device is actually subscribed
      final pushSubscription = OneSignal.User.pushSubscription;
      final isSubscribed = pushSubscription.optedIn ?? false;
      print('[NOTIF REG] Player ID: $playerId, Subscribed: $isSubscribed');

      if (!isSubscribed) {
        print('[NOTIF REG] ⚠️ Device is not opted-in to push notifications!');
        print('[NOTIF REG] Attempting to opt-in...');
        await pushSubscription.optIn();
        await Future.delayed(const Duration(seconds: 1));
        print('[NOTIF REG] Opt-in completed, new status: ${pushSubscription.optedIn}');
      }

      // Get auth token (using correct key from AuthService)
      final token = await _secureStorage.read(key: 'auth_jwt');
      if (token == null) {
        print('[NOTIF REG] No auth token available');
        return;
      }

      // Fetch user ID from /users/me API
      String? userId;
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/api/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          userId = data['id']?.toString();
          print('[NOTIF REG] Fetched user ID: $userId');
        } else {
          print('[NOTIF REG] Failed to fetch user ID: ${response.statusCode}');
          return;
        }
      } catch (e) {
        print('[NOTIF REG] Error fetching user ID: $e');
        return;
      }

      if (userId != null) {
        // Set external user ID in OneSignal
        print('[NOTIF REG] Setting OneSignal external user ID: $userId');
        OneSignal.login(userId);

        // Register device with backend
        print('[NOTIF REG] Registering device with backend...');
        final response = await http.post(
          Uri.parse('$_baseUrl/api/notifications/register-device'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'oneSignalPlayerId': playerId,
            'deviceType': Platform.isIOS ? 'ios' : 'android',
          }),
        );

        if (response.statusCode == 200) {
          print('[NOTIF REG] ✅ Device registered with backend: $playerId');
          print('[NOTIF REG] Response: ${response.body}');
        } else {
          print('[NOTIF REG] ❌ Failed to register device: ${response.statusCode}');
          print('[NOTIF REG] Response: ${response.body}');
        }
      }
    } catch (e) {
      print('[NOTIF REG] ❌ Failed to register device: $e');
    }
  }

  /// Show local notification when app is in foreground
  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'nexa_channel',
      'Nexa Notifications',
      channelDescription: 'Notifications for Nexa Staff app',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: json.encode(data),
    );
  }

  /// Handle local notification click
  void _handleLocalNotificationClick(NotificationResponse response) {
    // Parse payload and navigate
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        _handleNotificationClick(data);
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  /// Handle notification click navigation
  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'chat':
        _navigateToChat(data);
        break;
      case 'task':
        _navigateToTask(data);
        break;
      case 'event':
        _navigateToEvent(data);
        break;
      case 'hours':
        _navigateToTimesheet(data);
        break;
      default:
        // Navigate to notifications page
        _navigateToNotifications();
    }
  }

  /// Navigate to chat screen
  void _navigateToChat(Map<String, dynamic> data) {
    final conversationId = data['conversationId'];
    final managerId = data['managerId'];

    // TODO: Implement navigation to chat screen with manager
    print('Navigate to chat: $conversationId, manager: $managerId');
  }

  /// Navigate to task details
  void _navigateToTask(Map<String, dynamic> data) {
    final taskId = data['taskId'];
    final eventId = data['eventId'];

    // TODO: Implement navigation to task/event screen
    print('Navigate to task: $taskId, event: $eventId');
  }

  /// Navigate to event details
  void _navigateToEvent(Map<String, dynamic> data) {
    final eventId = data['eventId'];

    // TODO: Implement navigation to event screen
    print('Navigate to event: $eventId');
  }

  /// Navigate to timesheet
  void _navigateToTimesheet(Map<String, dynamic> data) {
    // TODO: Implement navigation to timesheet screen
    print('Navigate to timesheet');
  }

  /// Navigate to notifications list
  void _navigateToNotifications() {
    // TODO: Implement navigation to notifications screen
    print('Navigate to notifications list');
  }

  /// Update badge count based on notification data
  void _updateBadgeCount(Map<String, dynamic>? data) {
    if (data == null) return;

    final type = data['type'] as String?;

    switch (type) {
      case 'chat':
        _unreadChatCount++;
        break;
      case 'task':
        _unreadTaskCount++;
        break;
      case 'event':
        _unreadEventCount++;
        break;
    }

    _notificationCountController.add(totalUnreadCount);
  }

  /// Reset badge count for a specific type
  void resetBadgeCount(String type) {
    switch (type) {
      case 'chat':
        _unreadChatCount = 0;
        break;
      case 'task':
        _unreadTaskCount = 0;
        break;
      case 'event':
        _unreadEventCount = 0;
        break;
    }

    _notificationCountController.add(totalUnreadCount);
  }

  /// Load notification preferences
  Future<void> _loadNotificationPreferences() async {
    try {
      final token = await _secureStorage.read(key: 'auth_jwt');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = data['user']?['notificationPreferences'];
        if (prefs != null) {
          print('Loaded notification preferences: $prefs');
        }
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  /// Update notification preferences
  Future<bool> updatePreferences(Map<String, bool> preferences) async {
    try {
      final token = await _secureStorage.read(key: 'auth_jwt');
      if (token == null) return false;

      final response = await http.patch(
        Uri.parse('$_baseUrl/api/notifications/preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(preferences),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating preferences: $e');
      return false;
    }
  }

  /// Get notification history
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    try {
      final token = await _secureStorage.read(key: 'auth_jwt');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/notifications/history'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting notification history: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final token = await _secureStorage.read(key: 'auth_jwt');
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/mark-read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'notificationId': notificationId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking as read: $e');
      return false;
    }
  }

  /// Get unread count from server
  Future<int> getUnreadCount() async {
    try {
      final token = await _secureStorage.read(key: 'auth_jwt');
      if (token == null) return 0;

      final response = await http.get(
        Uri.parse('$_baseUrl/api/notifications/unread-count'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Send test notification
  Future<bool> sendTestNotification() async {
    try {
      final token = await _secureStorage.read(key: 'auth_jwt');
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/test'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': '🔔 Test Notification',
          'body': 'This is a test notification from Nexa Staff!',
          'type': 'system',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending test notification: $e');
      return false;
    }
  }

  /// Unregister device on logout
  Future<void> unregisterDevice() async {
    try {
      final deviceState = await OneSignal.User.getOnesignalId();
      final token = await _secureStorage.read(key: 'auth_jwt');

      if (deviceState != null && token != null) {
        await http.delete(
          Uri.parse('$_baseUrl/api/notifications/unregister-device'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'oneSignalPlayerId': deviceState}),
        );
      }

      // Clear OneSignal user
      OneSignal.logout();

      print('✅ Device unregistered');
    } catch (e) {
      print('❌ Failed to unregister device: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationCountController.close();
  }
}