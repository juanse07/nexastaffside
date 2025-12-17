import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

/// Service for managing user's terminology preferences
/// Handles storage and retrieval of preferred work assignment terminology
/// Language is auto-detected from phone settings (not stored)
/// Syncs with backend for push notification personalization
class TerminologyService {
  static const String _terminologyKey = 'user_terminology_preference';

  // Available terminology options (plural - for UI display)
  static const String shifts = 'shifts';
  static const String jobs = 'jobs';
  static const String events = 'events';

  // Available language options (for TerminologyHelper)
  static const String english = 'en';
  static const String spanish = 'es';

  // Default values
  static const String defaultTerminology = shifts;
  static const String defaultLanguage = english; // Used as fallback when locale can't be detected

  /// Convert plural (UI) to singular (backend)
  /// 'shifts' -> 'shift', 'jobs' -> 'job', 'events' -> 'event'
  static String toBackendFormat(String terminology) {
    switch (terminology) {
      case shifts:
        return 'shift';
      case jobs:
        return 'job';
      case events:
        return 'event';
      default:
        return 'shift';
    }
  }

  /// Convert singular (backend) to plural (UI)
  /// 'shift' -> 'shifts', 'job' -> 'jobs', 'event' -> 'events'
  static String fromBackendFormat(String? backendTerminology) {
    switch (backendTerminology) {
      case 'shift':
        return shifts;
      case 'job':
        return jobs;
      case 'event':
        return events;
      default:
        return defaultTerminology;
    }
  }

  /// Get the user's preferred terminology
  /// Returns 'shifts', 'jobs', or 'events'
  /// Defaults to 'shifts' if no preference is set
  static Future<String> getTerminology() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_terminologyKey) ?? defaultTerminology;
  }

  /// Set the user's preferred terminology
  /// Accepts 'shifts', 'jobs', or 'events'
  /// Also syncs to backend for push notification personalization
  static Future<bool> setTerminology(String terminology) async {
    if (terminology != shifts && terminology != jobs && terminology != events) {
      throw ArgumentError('Invalid terminology: $terminology. Must be shifts, jobs, or events.');
    }

    // Save locally first
    final prefs = await SharedPreferences.getInstance();
    final localSuccess = await prefs.setString(_terminologyKey, terminology);

    // Sync to backend (fire and forget - don't block UI)
    _syncToBackend(terminology);

    return localSuccess;
  }

  /// Sync terminology preference to backend
  /// Called when user changes preference
  static Future<void> _syncToBackend(String terminology) async {
    try {
      final backendValue = toBackendFormat(terminology);
      await UserService.updateMe(eventTerminology: backendValue);
      debugPrint('[TERMINOLOGY] Synced to backend: $backendValue');
    } catch (e) {
      // Don't throw - backend sync is best effort
      // Local storage is the source of truth for immediate UI
      debugPrint('[TERMINOLOGY] Backend sync failed (non-blocking): $e');
    }
  }

  /// Initialize terminology from backend (on app start/login)
  /// Syncs backend preference to local storage
  static Future<void> syncFromBackend() async {
    try {
      final profile = await UserService.getMe();
      if (profile.eventTerminology != null) {
        final localValue = fromBackendFormat(profile.eventTerminology);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_terminologyKey, localValue);
        debugPrint('[TERMINOLOGY] Synced from backend: ${profile.eventTerminology} -> $localValue');
      }
    } catch (e) {
      debugPrint('[TERMINOLOGY] Failed to sync from backend: $e');
    }
  }

  /// Clear terminology preference (reset to default)
  /// Language is never stored - it's auto-detected from phone
  static Future<bool> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_terminologyKey);
    return true;
  }
}
