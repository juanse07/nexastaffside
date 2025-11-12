import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user's terminology preferences
/// Handles storage and retrieval of preferred work assignment terminology
/// Language is auto-detected from phone settings (not stored)
class TerminologyService {
  static const String _terminologyKey = 'user_terminology_preference';

  // Available terminology options
  static const String shifts = 'shifts';
  static const String jobs = 'jobs';
  static const String events = 'events';

  // Available language options (for TerminologyHelper)
  static const String english = 'en';
  static const String spanish = 'es';

  // Default values
  static const String defaultTerminology = shifts;
  static const String defaultLanguage = english; // Used as fallback when locale can't be detected

  /// Get the user's preferred terminology
  /// Returns 'shifts', 'jobs', or 'events'
  /// Defaults to 'shifts' if no preference is set
  static Future<String> getTerminology() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_terminologyKey) ?? defaultTerminology;
  }

  /// Set the user's preferred terminology
  /// Accepts 'shifts', 'jobs', or 'events'
  static Future<bool> setTerminology(String terminology) async {
    if (terminology != shifts && terminology != jobs && terminology != events) {
      throw ArgumentError('Invalid terminology: $terminology. Must be shifts, jobs, or events.');
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_terminologyKey, terminology);
  }

  /// Clear terminology preference (reset to default)
  /// Language is never stored - it's auto-detected from phone
  static Future<bool> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_terminologyKey);
    return true;
  }
}
