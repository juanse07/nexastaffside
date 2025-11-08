import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for AI-powered message composition to help staff communicate professionally
/// with managers. Supports scenarios like running late, time off requests, translations, etc.
class MessageCompositionService {
  static const String baseUrl = 'https://api.nexapymesoft.com';

  /// Compose a professional message using AI based on the specified scenario
  ///
  /// [scenario] - The type of message to compose (late, timeoff, question, etc.)
  /// [message] - The original message to translate or polish
  /// [details] - Details for scenario-based composition (e.g., "15 minutes late due to traffic")
  /// [language] - Language preference: 'en', 'es', or 'auto' for automatic detection
  /// [authToken] - JWT token for authentication
  Future<ComposedMessageResponse> composeMessage({
    required MessageScenario scenario,
    String? message,
    String? details,
    String language = 'auto',
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/staff/compose-message'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'scenario': scenario.value,
          'context': {
            if (message != null) 'message': message,
            if (details != null) 'details': details,
            'language': language,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return ComposedMessageResponse.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 429) {
        throw MessageCompositionException(
          'Monthly message limit reached. Please upgrade to Pro or wait until next month.',
          code: 'LIMIT_REACHED',
        );
      } else if (response.statusCode == 401) {
        throw MessageCompositionException(
          'Authentication failed. Please log in again.',
          code: 'AUTH_FAILED',
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw MessageCompositionException(
          errorData['error'] ?? 'Failed to compose message',
          code: 'API_ERROR',
        );
      }
    } catch (e) {
      if (e is MessageCompositionException) {
        rethrow;
      }
      throw MessageCompositionException(
        'Network error. Please check your connection and try again.',
        code: 'NETWORK_ERROR',
      );
    }
  }
}

/// Enumeration of available message composition scenarios
enum MessageScenario {
  /// Translate message to English
  translate('translate', '🌐', 'Translate'),

  /// Make message professional, friendly, and concise
  professionalize('professionalize', '💼', 'Professional & Friendly'),

  /// Polish unprofessional message
  polish('polish', '✨', 'Polish Message'),

  /// Running late to a shift or event
  late('late', '🏃', 'Running Late'),

  /// Requesting time off
  timeoff('timeoff', '📅', 'Time Off Request'),

  /// Asking a question about shift/event
  question('question', '❓', 'Ask Question'),

  /// Custom message composition
  custom('custom', '✍️', 'Custom Message');

  const MessageScenario(this.value, this.emoji, this.displayName);

  final String value;
  final String emoji;
  final String displayName;
}

/// Response from the message composition API
class ComposedMessageResponse {
  /// The composed message in the original language
  final String original;

  /// English translation (if original was in Spanish)
  final String? translation;

  /// Detected language code ('en' or 'es')
  final String language;

  ComposedMessageResponse({
    required this.original,
    this.translation,
    required this.language,
  });

  factory ComposedMessageResponse.fromJson(Map<String, dynamic> json) {
    return ComposedMessageResponse(
      original: json['original'] as String,
      translation: json['translation'] as String?,
      language: json['language'] as String,
    );
  }

  /// Whether this message has a translation available
  bool get hasTranslation => translation != null && translation!.isNotEmpty;

  /// Get both messages formatted for display
  String get formattedMessages {
    if (hasTranslation) {
      return '$original\n\n🇬🇧 $translation';
    }
    return original;
  }
}

/// Custom exception for message composition errors
class MessageCompositionException implements Exception {
  final String message;
  final String code;

  MessageCompositionException(this.message, {required this.code});

  @override
  String toString() => message;
}
