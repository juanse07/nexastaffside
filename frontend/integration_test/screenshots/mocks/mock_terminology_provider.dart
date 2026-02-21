/// A test-friendly TerminologyProvider for the Staff app.
///
/// Skips SharedPreferences and TerminologyService async calls —
/// returns "Shifts" immediately for screenshot mode.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Standalone mock that mimics the Staff app's TerminologyProvider
/// without any SharedPreferences dependency.
class MockTerminologyProvider extends ChangeNotifier {
  String _terminology = 'shifts';
  String _systemLanguage = 'en';
  bool _isInitialized = true;

  MockTerminologyProvider({String terminology = 'shifts', String language = 'en'}) {
    _terminology = terminology;
    _systemLanguage = language;
  }

  String get terminology => _terminology;
  String get language => _systemLanguage;
  bool get isInitialized => _isInitialized;

  void updateSystemLanguage(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    _systemLanguage = (locale?.languageCode == 'es') ? 'es' : 'en';
  }

  Future<void> initialize() async {
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setTerminology(String terminology) async {
    _terminology = terminology;
    notifyListeners();
  }

  // Convenience getters matching the real provider
  String get singular {
    if (_systemLanguage == 'es') {
      switch (_terminology) {
        case 'shifts': return 'Turno';
        case 'jobs': return 'Trabajo';
        case 'events': return 'Evento';
        default: return 'Turno';
      }
    }
    switch (_terminology) {
      case 'shifts': return 'Shift';
      case 'jobs': return 'Job';
      case 'events': return 'Event';
      default: return 'Shift';
    }
  }

  String get plural {
    if (_systemLanguage == 'es') {
      switch (_terminology) {
        case 'shifts': return 'Turnos';
        case 'jobs': return 'Trabajos';
        case 'events': return 'Eventos';
        default: return 'Turnos';
      }
    }
    switch (_terminology) {
      case 'shifts': return 'Shifts';
      case 'jobs': return 'Jobs';
      case 'events': return 'Events';
      default: return 'Shifts';
    }
  }

  String get my => _systemLanguage == 'es' ? 'Mis ${plural}' : 'My $plural';

  String get lowercasePlural => plural.toLowerCase();

  String getCount(int count) => '$count ${lowercasePlural}';

  String get terminologyDisplayName => plural;
  String get languageDisplayName => _systemLanguage == 'es' ? 'Español' : 'English';

  Future<void> resetToDefaults() async {
    _terminology = 'shifts';
    notifyListeners();
  }
}
