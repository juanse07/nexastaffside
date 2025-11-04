import 'dart:convert';
// import 'package:qonversion_flutter/qonversion_flutter.dart'; // Temporarily disabled
import 'package:http/http.dart' as http;
import '../auth_service.dart';
import '../features/ai_assistant/config/app_config.dart';

/// Subscription Service
/// Handles Qonversion integration and subscription management
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool _initialized = false;
  String? _qonversionUserId;

  /// Initialize Qonversion SDK
  /// TEMPORARILY DISABLED - Will implement later
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('[SubscriptionService] Qonversion temporarily disabled - using free tier');
      _initialized = true;

      // TODO: Implement Qonversion integration later
      // final config = QonversionConfigBuilder(projectKey, QLaunchMode.subscriptionManagement);
      // await Qonversion.initialize(config.build());
    } catch (e) {
      print('[SubscriptionService] Initialization failed: $e');
    }
  }

  /// Get current subscription status
  /// TEMPORARILY DISABLED - Returns free tier
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // TODO: Implement Qonversion integration later
      // final entitlements = await Qonversion.getSharedInstance().checkEntitlements();

      return {'tier': 'free', 'isActive': false};
    } catch (e) {
      print('[SubscriptionService] Error getting status: $e');
      return {'tier': 'free', 'isActive': false};
    }
  }

  /// Purchase Pro subscription
  /// TEMPORARILY DISABLED
  Future<bool> purchaseProSubscription() async {
    try {
      print('[SubscriptionService] Purchase temporarily disabled');
      // TODO: Implement Qonversion purchase later
      return false;
    } catch (e) {
      print('[SubscriptionService] Purchase failed: $e');
      return false;
    }
  }

  /// Restore purchases
  /// TEMPORARILY DISABLED
  Future<bool> restorePurchases() async {
    try {
      print('[SubscriptionService] Restore temporarily disabled');
      // TODO: Implement Qonversion restore later
      return false;
    } catch (e) {
      print('[SubscriptionService] Restore failed: $e');
      return false;
    }
  }

  /// Get AI message usage statistics
  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[SubscriptionService] No auth token');
        return {};
      }

      final baseUrl = AIAssistantConfig.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/subscription/usage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('[SubscriptionService] Usage: ${data['used']}/${data['limit'] ?? 'unlimited'}');
        return data;
      }

      print('[SubscriptionService] Usage fetch failed: ${response.statusCode}');
      return {};
    } catch (e) {
      print('[SubscriptionService] Usage fetch error: $e');
      return {};
    }
  }

  /// Get subscription details from backend
  Future<Map<String, dynamic>> getBackendStatus() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[SubscriptionService] No auth token');
        return {};
      }

      final baseUrl = AIAssistantConfig.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/subscription/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('[SubscriptionService] Backend status: ${data['tier']}');
        return data;
      }

      print('[SubscriptionService] Backend status fetch failed: ${response.statusCode}');
      return {};
    } catch (e) {
      print('[SubscriptionService] Backend status error: $e');
      return {};
    }
  }

  /// Link Qonversion user ID to backend
  Future<void> _linkUserToBackend(String qonversionUserId) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[SubscriptionService] Cannot link user - no auth token');
        return;
      }

      final baseUrl = AIAssistantConfig.baseUrl;

      final response = await http.post(
        Uri.parse('$baseUrl/api/subscription/link-user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'qonversionUserId': qonversionUserId}),
      );

      if (response.statusCode == 200) {
        print('[SubscriptionService] User linked successfully');
      } else {
        print('[SubscriptionService] Link user failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[SubscriptionService] Link user error: $e');
    }
  }

  /// Sync subscription state with backend
  Future<void> _syncWithBackend() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[SubscriptionService] Cannot sync - no auth token');
        return;
      }

      final baseUrl = AIAssistantConfig.baseUrl;

      final response = await http.post(
        Uri.parse('$baseUrl/api/subscription/sync'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('[SubscriptionService] Sync successful');
      } else {
        print('[SubscriptionService] Sync failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[SubscriptionService] Sync error: $e');
    }
  }

  /// Check if user is Pro subscriber
  Future<bool> isPro() async {
    final status = await getSubscriptionStatus();
    return status['tier'] == 'pro' && status['isActive'] == true;
  }

  /// Get formatted usage string (e.g., "15/50" or "Unlimited")
  Future<String> getUsageString() async {
    final usage = await getUsageStats();

    if (usage['tier'] == 'pro') {
      return 'Unlimited';
    }

    final used = usage['used'] ?? 0;
    final limit = usage['limit'] ?? 50;
    return '$used/$limit';
  }
}
