import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../services/terminology_service.dart';
import '../utils/terminology_helper.dart';

/// Provider for managing terminology preferences across the app
/// Extends ChangeNotifier to enable reactive UI updates when terminology changes
/// Language is auto-detected from phone settings (like Manager app)
class TerminologyProvider extends ChangeNotifier {
  String _terminology = TerminologyService.defaultTerminology;
  String _systemLanguage = TerminologyService.defaultLanguage;
  bool _isInitialized = false;

  /// Current terminology preference ('shifts', 'jobs', or 'events')
  String get terminology => _terminology;

  /// Current language auto-detected from system locale ('en' or 'es')
  String get language => _systemLanguage;

  /// Whether the provider has loaded preferences from storage
  bool get isInitialized => _isInitialized;

  /// Initialize the provider by loading terminology preference from storage
  /// Language is NOT stored - it's auto-detected from phone settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _terminology = await TerminologyService.getTerminology();
      _isInitialized = true;
      notifyListeners();
      debugPrint('[TERMINOLOGY] Initialized: $_terminology (language will be auto-detected)');
    } catch (e) {
      debugPrint('[TERMINOLOGY] Error initializing: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Update system language based on BuildContext locale
  /// Automatically detects if phone is set to Spanish
  /// Should be called on each build to detect language changes
  void updateSystemLanguage(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final newLanguage = (locale?.languageCode == 'es')
        ? TerminologyHelper.spanish
        : TerminologyHelper.english;

    if (_systemLanguage != newLanguage) {
      _systemLanguage = newLanguage;
      notifyListeners();
      debugPrint('[TERMINOLOGY] System language auto-detected: $newLanguage');
    }
  }

  /// Update the terminology preference
  /// Saves to storage and notifies listeners to rebuild UI
  Future<void> setTerminology(String terminology) async {
    if (_terminology == terminology) return;

    try {
      await TerminologyService.setTerminology(terminology);
      _terminology = terminology;
      notifyListeners();
      debugPrint('[TERMINOLOGY] Updated to: $terminology');
    } catch (e) {
      debugPrint('[TERMINOLOGY] Error setting terminology: $e');
    }
  }

  // Convenience getters using TerminologyHelper

  /// Get singular form (e.g., "Shift", "Turno")
  String get singular => TerminologyHelper.getSingular(_terminology, _systemLanguage);

  /// Get plural form (e.g., "Shifts", "Turnos")
  String get plural => TerminologyHelper.getPlural(_terminology, _systemLanguage);

  /// Get possessive form (e.g., "My Shifts", "Mis Turnos")
  String get my => TerminologyHelper.getMy(_terminology, _systemLanguage);

  /// Get lowercase plural form (e.g., "shifts", "turnos")
  String get lowercasePlural => TerminologyHelper.getLowercasePlural(_terminology, _systemLanguage);

  /// Get count with proper terminology (e.g., "5 shifts", "5 turnos")
  String getCount(int count) => TerminologyHelper.getCount(count, _terminology, _systemLanguage);

  /// Get display name for current terminology
  String get terminologyDisplayName =>
      TerminologyHelper.getTerminologyDisplayName(_terminology, _systemLanguage);

  /// Get display name for current language
  String get languageDisplayName => TerminologyHelper.getLanguageDisplayName(_systemLanguage);

  /// Reset terminology to default (language stays auto-detected)
  Future<void> resetToDefaults() async {
    try {
      await TerminologyService.clearPreferences();
      _terminology = TerminologyService.defaultTerminology;
      notifyListeners();
      debugPrint('[TERMINOLOGY] Reset to default terminology');
    } catch (e) {
      debugPrint('[TERMINOLOGY] Error resetting: $e');
    }
  }
}
