import 'dart:convert';
import 'package:qonversion_flutter/qonversion_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // Cached subscription state from backend
  bool _isReadOnly = false;
  bool _isInFreeMonth = false;
  int _freeMonthDaysRemaining = 0;
  bool _statusLoaded = false;

  bool get isReadOnly => _isReadOnly;
  bool get isInFreeMonth => _isInFreeMonth;
  int get freeMonthDaysRemaining => _freeMonthDaysRemaining;
  bool get statusLoaded => _statusLoaded;
  bool canPerformAction() => !_isReadOnly;

  /// Initialize Qonversion SDK
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get Qonversion project key from environment
      final projectKey = dotenv.env['QONVERSION_PROJECT_KEY'];
      if (projectKey == null || projectKey.isEmpty) {
        print('[SubscriptionService] QONVERSION_PROJECT_KEY not found in .env - subscription features disabled');
        _initialized = true;
        return;
      }

      print('[SubscriptionService] Initializing Qonversion SDK...');

      // Initialize Qonversion SDK (static method)
      final config = QonversionConfigBuilder(
        projectKey,
        QLaunchMode.subscriptionManagement,
      ).build();
      Qonversion.initialize(config);

      // Get Qonversion user info
      final userInfo = await Qonversion.getSharedInstance().userInfo();
      _qonversionUserId = userInfo.qonversionId;
      print('[SubscriptionService] Qonversion initialized, user ID: $_qonversionUserId');

      // Link to backend
      if (_qonversionUserId != null && _qonversionUserId!.isNotEmpty) {
        await _linkUserToBackend(_qonversionUserId!);
      }

      _initialized = true;
    } catch (e) {
      print('[SubscriptionService] Initialization failed: $e');
      _initialized = true; // Mark as initialized even on error to prevent retry loops
    }
  }

  /// Get current subscription status from Qonversion
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // If Qonversion isn't configured, return free tier
      if (_qonversionUserId == null) {
        return {'tier': 'free', 'isActive': false};
      }

      // Check Qonversion entitlements
      final entitlements = await Qonversion.getSharedInstance().checkEntitlements();

      // Look for 'pro_access' entitlement (matches Qonversion dashboard ID)
      final proEntitlement = entitlements['pro_access'];
      final isActive = proEntitlement != null && proEntitlement.isActive;

      print('[SubscriptionService] Status check: ${isActive ? 'Pro' : 'Free'}');

      // Sync with backend to keep database in sync
      await _syncWithBackend();

      return {
        'tier': isActive ? 'pro' : 'free',
        'isActive': isActive,
        'expirationDate': proEntitlement?.expirationDate?.toIso8601String(),
      };
    } catch (e) {
      print('[SubscriptionService] Error getting status: $e');
      return {'tier': 'free', 'isActive': false};
    }
  }

  /// Purchase Pro subscription ($7.80/month)
  Future<bool> purchaseProSubscription() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // If Qonversion isn't configured, return false
      if (_qonversionUserId == null) {
        print('[SubscriptionService] Cannot purchase - Qonversion not initialized');
        return false;
      }

      // Get available offerings
      final offerings = await Qonversion.getSharedInstance().offerings();
      final mainOffering = offerings.main;

      if (mainOffering == null) {
        print('[SubscriptionService] No offerings available');
        return false;
      }

      // Find Pro subscription product (monthly subscription)
      // Products are accessed from the products list
      QProduct? proProduct;
      for (final product in mainOffering.products) {
        if (product.qonversionId == 'flowshift_staff_pro_monthly') {
          proProduct = product;
          break;
        }
      }

      if (proProduct == null) {
        print('[SubscriptionService] Pro product not found');
        return false;
      }

      print('[SubscriptionService] Purchasing ${proProduct.qonversionId}...');

      // Purchase using purchaseProduct method
      final result = await Qonversion.getSharedInstance().purchaseProduct(proProduct);

      // Check if purchase was successful
      final isActive = result['pro_access']?.isActive ?? false;

      if (isActive) {
        print('[SubscriptionService] Purchase successful!');
        // Sync with backend
        await _syncWithBackend();
      } else {
        print('[SubscriptionService] Purchase completed but entitlement not active');
      }

      return isActive;
    } catch (e) {
      print('[SubscriptionService] Purchase failed: $e');
      return false;
    }
  }

  /// Restore purchases (for users who already subscribed on another device)
  Future<bool> restorePurchases() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // If Qonversion isn't configured, return false
      if (_qonversionUserId == null) {
        print('[SubscriptionService] Cannot restore - Qonversion not initialized');
        return false;
      }

      // Restore purchases from App Store/Google Play
      final entitlements = await Qonversion.getSharedInstance().restore();

      // Check if Pro entitlement is active
      final isActive = entitlements['pro_access']?.isActive ?? false;

      if (isActive) {
        print('[SubscriptionService] Subscription restored!');
        // Sync with backend
        await _syncWithBackend();
      } else {
        print('[SubscriptionService] No active subscription found');
      }

      return isActive;
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

  /// Get subscription details from backend and cache read-only state
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

        // Cache subscription state
        _isReadOnly = data['isReadOnly'] == true;
        final freeMonth = data['freeMonth'] as Map<String, dynamic>?;
        if (freeMonth != null) {
          _isInFreeMonth = freeMonth['active'] == true;
          _freeMonthDaysRemaining = (freeMonth['daysRemaining'] as num?)?.toInt() ?? 0;
        }
        _statusLoaded = true;

        print('[SubscriptionService] readOnly=$_isReadOnly, freeMonth=$_isInFreeMonth, daysRemaining=$_freeMonthDaysRemaining');
        return data;
      }

      print('[SubscriptionService] Backend status fetch failed: ${response.statusCode}');
      return {};
    } catch (e) {
      print('[SubscriptionService] Backend status error: $e');
      return {};
    }
  }

  /// Refresh subscription state after a purchase or restore
  Future<void> refreshStatus() async {
    await getBackendStatus();
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
