import 'dart:convert';
import 'package:qonversion_flutter/qonversion_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../auth_service.dart';
import '../features/ai_assistant/config/app_config.dart';

/// Subscription Service
/// Handles Qonversion integration and subscription management.
/// Supports two paid tiers: Starter ($6.99) and Pro ($11.99).
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
  String _tier = 'free'; // 'free' | 'starter' | 'pro' | 'premium'

  bool get isReadOnly => _isReadOnly;
  bool get isInFreeMonth => _isInFreeMonth;
  int get freeMonthDaysRemaining => _freeMonthDaysRemaining;
  bool get statusLoaded => _statusLoaded;
  String get tier => _tier;
  bool canPerformAction() => !_isReadOnly;

  /// Whether the user has any active paid subscription (starter or pro)
  bool get isSubscribed => _tier == 'starter' || _tier == 'pro' || _tier == 'premium';

  /// Reset singleton state on logout so re-login re-initializes properly
  void reset() {
    _initialized = false;
    _qonversionUserId = null;
    _isReadOnly = false;
    _isInFreeMonth = false;
    _freeMonthDaysRemaining = 0;
    _statusLoaded = false;
    _tier = 'free';
    print('[SubscriptionService] State reset for logout');
  }

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

  /// Get current subscription status from Qonversion.
  /// Checks both 'pro_access' and 'starter_access' entitlements.
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

      // Check Pro first (higher priority), then Starter
      final proEntitlement = entitlements['pro_access'];
      final starterEntitlement = entitlements['starter_access'];

      String detectedTier = 'free';
      bool isActive = false;
      QEntitlement? activeEntitlement;

      if (proEntitlement != null && proEntitlement.isActive) {
        detectedTier = 'pro';
        isActive = true;
        activeEntitlement = proEntitlement;
      } else if (starterEntitlement != null && starterEntitlement.isActive) {
        detectedTier = 'starter';
        isActive = true;
        activeEntitlement = starterEntitlement;
      }

      print('[SubscriptionService] Status check: $detectedTier (active=$isActive)');

      // Sync with backend to keep database in sync
      if (isActive) {
        await _syncWithBackend(tier: detectedTier, status: 'active');
      } else {
        await _syncWithBackend();
      }

      return {
        'tier': detectedTier,
        'isActive': isActive,
        'expirationDate': activeEntitlement?.expirationDate?.toIso8601String(),
      };
    } catch (e) {
      print('[SubscriptionService] Error getting status: $e');
      return {'tier': 'free', 'isActive': false};
    }
  }

  /// Purchase Plus subscription ($5.99/month)
  Future<({bool success, String? error})> purchasePlusSubscription() async {
    return _purchaseSubscription('flowshift_staff_plus_monthly', 'plus_access', 'plus');
  }

  /// Purchase Starter subscription (legacy — kept for existing subscribers)
  Future<({bool success, String? error})> purchaseStarterSubscription() async {
    return _purchaseSubscription('flowshift_staff_starter_monthly', 'starter_access', 'starter');
  }

  /// Purchase Pro subscription (legacy — kept for existing subscribers)
  Future<({bool success, String? error})> purchaseProSubscription() async {
    return _purchaseSubscription('flowshift_shifts_pro_monthly', 'pro_access', 'pro');
  }

  /// Generic purchase method for any tier.
  Future<({bool success, String? error})> _purchaseSubscription(
    String productId,
    String entitlementId,
    String tierName,
  ) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      if (_qonversionUserId == null) {
        const msg = 'Qonversion not initialized (no user ID)';
        print('[SubscriptionService] $msg');
        return (success: false, error: msg);
      }

      // Get available offerings
      print('[SubscriptionService] Fetching offerings...');
      final offerings = await Qonversion.getSharedInstance().offerings();
      final mainOffering = offerings.main;

      if (mainOffering == null) {
        final availableIds = offerings.availableOfferings.map((o) => o.id).toList();
        final msg = 'No main offering. Available: $availableIds';
        print('[SubscriptionService] $msg');
        return (success: false, error: msg);
      }

      // Log all products in the offering for diagnostics
      final productIds = mainOffering.products.map((p) => '${p.qonversionId}(store:${p.storeId}, skProduct:${p.skProduct != null})').toList();
      print('[SubscriptionService] Main offering "${mainOffering.id}" products: $productIds');

      // Find the target product
      QProduct? targetProduct;
      for (final product in mainOffering.products) {
        if (product.qonversionId == productId) {
          targetProduct = product;
          break;
        }
      }

      if (targetProduct == null) {
        final msg = 'Product "$productId" not in offering. Found: $productIds';
        print('[SubscriptionService] $msg');
        return (success: false, error: msg);
      }

      print('[SubscriptionService] Found product: qId=${targetProduct.qonversionId}, storeId=${targetProduct.storeId}, '
          'prettyPrice=${targetProduct.prettyPrice}, skProduct=${targetProduct.skProduct != null}, '
          'type=${targetProduct.type}');
      if (targetProduct.skProduct == null) {
        final msg = 'StoreKit product not resolved — storeId "${targetProduct.storeId}" may not exist in App Store Connect';
        print('[SubscriptionService] WARNING: $msg');
      }
      print('[SubscriptionService] Purchasing ${targetProduct.qonversionId}...');

      // Purchase using purchaseProduct method
      final result = await Qonversion.getSharedInstance().purchaseProduct(targetProduct);

      // Log all returned entitlements
      final entKeys = result.keys.toList();
      print('[SubscriptionService] Purchase returned entitlements: $entKeys');
      for (final key in entKeys) {
        final ent = result[key];
        print('[SubscriptionService]   $key → isActive=${ent?.isActive}, renewState=${ent?.renewState}');
      }

      // Check if purchase was successful — accept any active entitlement
      // (Qonversion may map products to different entitlements than expected)
      String? activeTier;
      if (result['pro_access']?.isActive ?? false) {
        activeTier = 'pro';
      } else if (result['starter_access']?.isActive ?? false) {
        activeTier = 'starter';
      }

      if (activeTier != null) {
        // Use the tier from the entitlement if it differs from expected
        final effectiveTier = activeTier;
        print('[SubscriptionService] Purchase successful ($effectiveTier)!');
        await _syncWithBackend(tier: effectiveTier, status: 'active');
        return (success: true, error: null);
      } else {
        final msg = 'Purchase completed but no active entitlement. Keys: $entKeys';
        print('[SubscriptionService] $msg');
        return (success: false, error: msg);
      }
    } catch (e) {
      final errorStr = e.toString();
      print('[SubscriptionService] Purchase failed: $errorStr');
      // No auto-restore — user can tap "Restore Purchase" manually if needed.
      // Auto-restore was masking real StoreKit errors by returning stale
      // Qonversion server-side entitlements.
      return (success: false, error: 'Purchase error: $errorStr');
    }
  }

  /// Restore purchases (for users who already subscribed on another device).
  /// Checks both pro_access and starter_access entitlements.
  Future<bool> restorePurchases() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      if (_qonversionUserId == null) {
        print('[SubscriptionService] Cannot restore - Qonversion not initialized');
        return false;
      }

      // Restore purchases from App Store/Google Play
      final entitlements = await Qonversion.getSharedInstance().restore();

      // Check Pro first, then Starter
      String? restoredTier;
      if (entitlements['pro_access']?.isActive ?? false) {
        restoredTier = 'pro';
      } else if (entitlements['starter_access']?.isActive ?? false) {
        restoredTier = 'starter';
      }

      if (restoredTier != null) {
        print('[SubscriptionService] Subscription restored ($restoredTier)!');
        await _syncWithBackend(tier: restoredTier, status: 'active');
        return true;
      } else {
        print('[SubscriptionService] No active subscription found');
        return false;
      }
    } catch (e) {
      print('[SubscriptionService] Restore failed: $e');
      return false;
    }
  }

  /// Get AI message usage statistics
  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final baseUrl = AIAssistantConfig.baseUrl;
      final response = await AuthService.httpClient.get(
        Uri.parse('$baseUrl/api/subscription/usage'),
        headers: {'Content-Type': 'application/json'},
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
      final baseUrl = AIAssistantConfig.baseUrl;
      final response = await AuthService.httpClient.get(
        Uri.parse('$baseUrl/api/subscription/status'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('[SubscriptionService] Backend status: ${data['tier']}');

        // Cache subscription state
        _isReadOnly = data['isReadOnly'] == true;
        _tier = (data['tier'] as String?) ?? 'free';
        final freeMonth = data['freeMonth'] as Map<String, dynamic>?;
        if (freeMonth != null) {
          _isInFreeMonth = freeMonth['active'] == true;
          _freeMonthDaysRemaining = (freeMonth['daysRemaining'] as num?)?.toInt() ?? 0;
        }
        _statusLoaded = true;

        print('[SubscriptionService] readOnly=$_isReadOnly, tier=$_tier, freeMonth=$_isInFreeMonth, daysRemaining=$_freeMonthDaysRemaining');
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

  /// Check Qonversion entitlements and sync with backend if active.
  /// Call this on app launch to catch subscriptions the backend doesn't know about.
  Future<void> syncEntitlementsOnLaunch() async {
    try {
      if (_qonversionUserId == null) return;

      final entitlements = await Qonversion.getSharedInstance().checkEntitlements();

      // Check Pro first, then Starter
      String? activeTier;
      if (entitlements['pro_access']?.isActive ?? false) {
        activeTier = 'pro';
      } else if (entitlements['starter_access']?.isActive ?? false) {
        activeTier = 'starter';
      }

      print('[SubscriptionService] Launch entitlement check: ${activeTier ?? 'Free'}');

      // If Apple says active but backend says read-only, sync to fix the mismatch
      if (activeTier != null && _isReadOnly) {
        print('[SubscriptionService] Mismatch detected — Apple active ($activeTier) but backend read-only, syncing...');
        await _syncWithBackend(tier: activeTier, status: 'active');
        await getBackendStatus(); // Reload cached state
      }
    } catch (e) {
      print('[SubscriptionService] Launch entitlement sync error: $e');
    }
  }

  /// Link Qonversion user ID to backend
  Future<void> _linkUserToBackend(String qonversionUserId) async {
    try {
      final baseUrl = AIAssistantConfig.baseUrl;

      final response = await AuthService.httpClient.post(
        Uri.parse('$baseUrl/api/subscription/link-user'),
        headers: {'Content-Type': 'application/json'},
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

  /// Sync subscription state with backend.
  /// When [tier] and [status] are provided (after a purchase/restore), the
  /// backend updates the user's subscription record in MongoDB.
  Future<void> _syncWithBackend({String? tier, String? status}) async {
    try {
      final baseUrl = AIAssistantConfig.baseUrl;
      final body = <String, dynamic>{};
      if (tier != null) body['tier'] = tier;
      if (status != null) body['status'] = status;

      final response = await AuthService.httpClient.post(
        Uri.parse('$baseUrl/api/subscription/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print('[SubscriptionService] Sync successful: ${response.body}');
      } else {
        print('[SubscriptionService] Sync failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[SubscriptionService] Sync error: $e');
    }
  }

  /// Check if user has any active subscription (starter or pro)
  Future<bool> isPro() async {
    final status = await getSubscriptionStatus();
    return status['isActive'] == true;
  }

  /// Get formatted usage string (e.g., "15/25" or "2/3")
  Future<String> getUsageString() async {
    final usage = await getUsageStats();
    final used = usage['used'] ?? 0;
    final limit = usage['limit'];
    if (limit == null) return '$used';
    return '$used/$limit';
  }
}
