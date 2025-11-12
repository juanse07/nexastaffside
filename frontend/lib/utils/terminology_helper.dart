/// Helper class for translating terminology between English and Spanish
/// Provides consistent translations for shifts/jobs/events terminology
class TerminologyHelper {
  // Terminology constants
  static const String shifts = 'shifts';
  static const String jobs = 'jobs';
  static const String events = 'events';

  // Language constants
  static const String english = 'en';
  static const String spanish = 'es';

  /// Translation maps for each terminology option
  static const Map<String, Map<String, Map<String, String>>> _translations = {
    shifts: {
      english: {
        'singular': 'Shift',
        'plural': 'Shifts',
        'my': 'My Shifts',
        'lowercase_plural': 'shifts',
      },
      spanish: {
        'singular': 'Turno',
        'plural': 'Turnos',
        'my': 'Mis Turnos',
        'lowercase_plural': 'turnos',
      },
    },
    jobs: {
      english: {
        'singular': 'Job',
        'plural': 'Jobs',
        'my': 'My Jobs',
        'lowercase_plural': 'jobs',
      },
      spanish: {
        'singular': 'Trabajo',
        'plural': 'Trabajos',
        'my': 'Mis Trabajos',
        'lowercase_plural': 'trabajos',
      },
    },
    events: {
      english: {
        'singular': 'Event',
        'plural': 'Events',
        'my': 'My Events',
        'lowercase_plural': 'events',
      },
      spanish: {
        'singular': 'Evento',
        'plural': 'Eventos',
        'my': 'Mis Eventos',
        'lowercase_plural': 'eventos',
      },
    },
  };

  /// Get singular form (e.g., "Shift", "Turno")
  static String getSingular(String terminology, String language) {
    return _translations[terminology]?[language]?['singular'] ?? 'Shift';
  }

  /// Get plural form (e.g., "Shifts", "Turnos")
  static String getPlural(String terminology, String language) {
    return _translations[terminology]?[language]?['plural'] ?? 'Shifts';
  }

  /// Get possessive form (e.g., "My Shifts", "Mis Turnos")
  static String getMy(String terminology, String language) {
    return _translations[terminology]?[language]?['my'] ?? 'My Shifts';
  }

  /// Get lowercase plural form (e.g., "shifts", "turnos")
  /// Useful for inline text and badges
  static String getLowercasePlural(String terminology, String language) {
    return _translations[terminology]?[language]?['lowercase_plural'] ?? 'shifts';
  }

  /// Get count with proper terminology (e.g., "5 shifts", "5 turnos")
  static String getCount(int count, String terminology, String language) {
    final term = count == 1
        ? getSingular(terminology, language).toLowerCase()
        : getLowercasePlural(terminology, language);
    return '$count $term';
  }

  /// Get display name for terminology option (for settings UI)
  static String getTerminologyDisplayName(String terminology, String language) {
    if (language == spanish) {
      switch (terminology) {
        case shifts:
          return 'Turnos';
        case jobs:
          return 'Trabajos';
        case events:
          return 'Eventos';
        default:
          return 'Turnos';
      }
    } else {
      switch (terminology) {
        case shifts:
          return 'Shifts';
        case jobs:
          return 'Jobs';
        case events:
          return 'Events';
        default:
          return 'Shifts';
      }
    }
  }

  /// Get language display name for settings UI
  static String getLanguageDisplayName(String language) {
    switch (language) {
      case english:
        return 'English';
      case spanish:
        return 'Español';
      default:
        return 'English';
    }
  }

  /// Get all available terminology options for a language
  static List<String> getTerminologyOptions() {
    return [shifts, jobs, events];
  }

  /// Get all available language options
  static List<String> getLanguageOptions() {
    return [english, spanish];
  }
}
