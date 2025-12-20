import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../auth_service.dart';
import '../config/app_config.dart';

/// AI Provider enum
enum AIProvider { openai, claude, groq }

/// Chat message model
class ChatMessage {
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;
  final AIProvider? provider;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.provider,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

/// Staff Chat Service
/// Handles AI interactions for staff members
class StaffChatService {
  final List<ChatMessage> _conversationHistory = [];
  AIProvider _selectedProvider = AIProvider.groq; // Always use Groq (LLAMA/GPT-OSS)
  bool _isLoading = false;

  // Staff-specific context
  Map<String, dynamic>? _staffContext;
  DateTime? _contextLoadedAt;
  static const _contextCacheDuration = Duration(minutes: 30); // Extended for better performance

  // System instructions (loaded from markdown asset)
  String? _systemInstructions;

  // Cached system message to avoid rebuilding on every API call
  String? _cachedSystemMessage;
  DateTime? _systemMessageBuiltAt;

  // Pending actions (availability, shift acceptance/decline)
  Map<String, dynamic>? _pendingAvailability;
  Map<String, dynamic>? _pendingShiftAction;

  // Conversation tracking for summaries
  DateTime? _conversationStartTime;
  String _inputSource = 'text'; // 'text' or 'voice'
  String _aiModel = 'llama-3.1-8b-instant';
  String _aiProvider = 'groq';

  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  AIProvider get selectedProvider => _selectedProvider;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get pendingAvailability => _pendingAvailability;
  Map<String, dynamic>? get pendingShiftAction => _pendingShiftAction;
  DateTime? get conversationStartTime => _conversationStartTime;

  /// Initialize the service (load system instructions)
  Future<void> initialize() async {
    try {
      // Load system instructions from assets
      // TODO: Load from assets when markdown file is added
      _systemInstructions = _getDefaultSystemInstructions();
      print('[StaffChatService] Initialized with system instructions');
    } catch (e) {
      print('[StaffChatService] Failed to load system instructions: $e');
      _systemInstructions = _getDefaultSystemInstructions();
    }
  }

  /// Get default system instructions (inline fallback)
  String _getDefaultSystemInstructions({String? terminology}) {
    final workTerm = terminology ?? 'shifts';
    final workTermSingular = _getSingularForm(workTerm);

    return '''
You are a helpful AI assistant for staff members in an event staffing system.

IMPORTANT: Use "$workTerm" terminology when referring to work assignments (not "shifts", "jobs", or "events" unless that's the user's preference).

You can help with:
- Viewing upcoming $workTerm and schedule
- Marking availability (available/unavailable/preferred dates)
- Accepting or declining $workTermSingular offers
- Tracking earnings and hours worked
- Answering questions about assigned $workTerm

Be friendly, concise, and helpful. Use emojis occasionally to make conversations engaging.

When responding about schedule, be specific with dates, times, venues, and roles.
When marking availability or accepting/declining $workTerm, use the appropriate response formats.
''';
  }

  /// Get singular form of terminology
  String _getSingularForm(String plural) {
    if (plural.toLowerCase() == 'shifts') return 'shift';
    if (plural.toLowerCase() == 'events') return 'event';
    if (plural.toLowerCase() == 'jobs') return 'job';
    // Fallback: remove 's'
    return plural.endsWith('s') ? plural.substring(0, plural.length - 1) : plural;
  }

  /// Load staff context from backend
  Future<Map<String, dynamic>?> _loadStaffContext({bool force = false}) async {
    try {
      // Check if context is still fresh
      if (!force &&
          _staffContext != null &&
          _contextLoadedAt != null &&
          DateTime.now().difference(_contextLoadedAt!) < _contextCacheDuration) {
        print('[StaffChatService] Using cached staff context');
        return _staffContext;
      }

      final token = await AuthService.getJwt();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final baseUrl = AIAssistantConfig.baseUrl;
      final endpoint = '/api/ai/staff/context';
      final fullUrl = '$baseUrl$endpoint';
      final uri = Uri.parse(fullUrl);

      print('[StaffChatService] Loading staff context from: $fullUrl');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _staffContext = jsonDecode(response.body);
        _contextLoadedAt = DateTime.now();
        print('[StaffChatService] Staff context loaded successfully');
        return _staffContext;
      } else {
        print('[StaffChatService] Failed to load context: ${response.statusCode}');
        print('[StaffChatService] Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('[StaffChatService] Error loading staff context: $e');
      return null;
    }
  }

  /// Build system message with context
  /// Cached to avoid rebuilding the same message repeatedly
  Future<String> _buildSystemMessage({String? terminology}) async {
    // Check if we have a valid cached system message
    // Cache is valid if context hasn't changed and was recently loaded
    if (_cachedSystemMessage != null &&
        _systemMessageBuiltAt != null &&
        _contextLoadedAt != null &&
        _systemMessageBuiltAt == _contextLoadedAt) {
      return _cachedSystemMessage!;
    }

    final context = await _loadStaffContext();

    final buffer = StringBuffer();
    buffer.writeln(_systemInstructions ?? _getDefaultSystemInstructions(terminology: terminology));
    buffer.writeln();

    if (context != null) {
      buffer.writeln('## Your Staff Context');
      buffer.writeln();

      // User info
      final user = context['user'];
      if (user != null) {
        buffer.writeln('**Your Profile:**');
        buffer.writeln('Name: ${user['firstName']} ${user['lastName']}');
        buffer.writeln('Email: ${user['email']}');
        if (user['phoneNumber'] != null) {
          buffer.writeln('Phone: ${user['phoneNumber']}');
        }
        buffer.writeln();
      }

      // Assigned events
      final assignedEvents = context['assignedEvents'] as List?;
      if (assignedEvents != null && assignedEvents.isNotEmpty) {
        buffer.writeln('**Your Assigned Events (${assignedEvents.length} total):**');
        buffer.writeln();

        for (var event in assignedEvents) {
          buffer.writeln('Event ID: ${event['_id']}');
          buffer.writeln('  Name: ${event['shift_name']}');
          buffer.writeln('  Client: ${event['client_name']}');
          buffer.writeln('  Date: ${event['date']}');
          buffer.writeln('  Your Role: ${event['userRole']}');
          if (event['userCallTime'] != null) {
            buffer.writeln('  Call Time: ${event['userCallTime']}');
          }
          if (event['start_time'] != null) {
            buffer.writeln('  Event Time: ${event['start_time']} - ${event['end_time']}');
          }
          if (event['venue_name'] != null) {
            buffer.writeln('  Venue: ${event['venue_name']}');
          }
          if (event['venue_address'] != null) {
            buffer.writeln('  Address: ${event['venue_address']}');
          }
          buffer.writeln('  Status: ${event['userStatus']}');
          if (event['userPayRate'] != null) {
            buffer.writeln('  Pay Rate: \$${event['userPayRate']}/hour');
          }
          buffer.writeln();
        }
      } else {
        buffer.writeln('**Your Assigned Events:** None currently assigned');
        buffer.writeln();
      }

      // Earnings
      final earnings = context['earnings'];
      if (earnings != null) {
        buffer.writeln('**Your Earnings:**');
        buffer.writeln('Total Earned: \$${earnings['totalEarnings']}');
        buffer.writeln('Total Hours: ${earnings['totalHoursWorked']} hours');
        buffer.writeln();
      }

      // Availability History
      final availabilityHistory = context['availabilityHistory'] as List?;
      if (availabilityHistory != null && availabilityHistory.isNotEmpty) {
        buffer.writeln('**Your Availability History (last 90 days):**');
        buffer.writeln();

        for (var record in availabilityHistory) {
          buffer.writeln('Date: ${record['date']}');
          buffer.writeln('  Status: ${record['status']}');
          buffer.writeln('  Time: ${record['timeRange']}');
          buffer.writeln();
        }
      } else {
        buffer.writeln('**Your Availability History:** None marked yet');
        buffer.writeln();
      }

      // Team info
      final teamInfo = context['teamInfo'];
      if (teamInfo != null) {
        buffer.writeln('**Team Information:**');
        buffer.writeln('Company: ${teamInfo['companyName']}');
        if (teamInfo['supportEmail'] != null) {
          buffer.writeln('Support Email: ${teamInfo['supportEmail']}');
        }
        if (teamInfo['supportPhone'] != null) {
          buffer.writeln('Support Phone: ${teamInfo['supportPhone']}');
        }
        buffer.writeln();
      }
    }

    // Cache the built message
    _cachedSystemMessage = buffer.toString();
    _systemMessageBuiltAt = _contextLoadedAt;

    return _cachedSystemMessage!;
  }

  /// Send a message to the AI
  Future<ChatMessage?> sendMessage(String userMessage, {String? modelPreference, String? terminology}) async {
    try {
      _isLoading = true;

      // Add user message to history
      final userChatMessage = ChatMessage(
        role: 'user',
        content: userMessage,
      );
      _conversationHistory.add(userChatMessage);

      // Build messages array for AI
      final messages = <Map<String, dynamic>>[];

      // Add system message with context
      final systemMessage = await _buildSystemMessage(terminology: terminology);
      messages.add({
        'role': 'system',
        'content': systemMessage,
      });

      // Add conversation history
      for (final msg in _conversationHistory) {
        messages.add(msg.toJson());
      }

      // Call AI backend
      final token = await AuthService.getJwt();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final baseUrl = AIAssistantConfig.baseUrl;
      final endpoint = '/api/ai/staff/chat/message';
      final fullUrl = '$baseUrl$endpoint';
      final uri = Uri.parse(fullUrl);

      // Map UI model names to Groq API model names
      String? groqModel;
      if (modelPreference != null) {
        if (modelPreference == 'llama') {
          groqModel = 'llama-3.1-8b-instant';
        } else if (modelPreference == 'gpt-oss') {
          groqModel = 'openai/gpt-oss-20b';
        } else {
          groqModel = modelPreference; // Pass through if already full name
        }
      }

      print('[StaffChatService] Sending message to: $fullUrl (${_selectedProvider.name}, model: ${groqModel ?? "default"})');

      // Build request body
      final requestBody = {
        'messages': messages,
        'temperature': 0.7,
        'maxTokens': 500,
        'provider': _selectedProvider.name, // Always 'groq'
      };

      // Add model if specified
      if (groqModel != null) {
        requestBody['model'] = groqModel;
      }

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      _isLoading = false;

      // Handle 402 Payment Required (message limit reached)
      if (response.statusCode == 402) {
        final errorData = jsonDecode(response.body);
        final message = errorData['message'] ?? 'Message limit reached. Upgrade to Pro for unlimited messages.';
        final usage = errorData['usage'];

        print('[StaffChatService] Message limit reached: $message');

        // Add system message showing upgrade prompt
        final upgradeMessage = ChatMessage(
          role: 'system',
          content: '⚠️ $message\n\nTap the usage indicator above to upgrade to Pro!',
        );
        _conversationHistory.add(upgradeMessage);

        return upgradeMessage;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as String?;
        final provider = data['provider'] as String?;

        if (content != null && content.isNotEmpty) {
          print('[StaffChatService] AI response received: ${content.substring(0, content.length > 100 ? 100 : content.length)}...');

          // Parse response for special commands (uses raw content)
          _parseResponseForActions(content);

          // Strip JSON command blocks before storing for display
          final userFacingContent = _extractUserFriendlyMessage(content);

          // Add AI response to history (with cleaned content)
          final aiMessage = ChatMessage(
            role: 'assistant',
            content: userFacingContent,
            provider: provider == 'claude'
                ? AIProvider.claude
                : provider == 'groq'
                    ? AIProvider.groq
                    : AIProvider.openai,
          );
          _conversationHistory.add(aiMessage);

          return aiMessage;
        } else {
          print('[StaffChatService] Empty response from AI');
          return null;
        }
      } else {
        print('[StaffChatService] AI request failed: ${response.statusCode}');
        print('[StaffChatService] Response: ${response.body}');
        _isLoading = false;

        // Try to extract error message
        try {
          final errorData = jsonDecode(response.body);
          final message = errorData['message'] ?? 'Failed to get AI response';
          throw Exception(message);
        } catch (e) {
          throw Exception('Failed to get AI response: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('[StaffChatService] Error sending message: $e');
      _isLoading = false;
      return null;
    }
  }

  /// Extract user-friendly message by removing technical markers and JSON
  /// This hides AVAILABILITY_MARK, SHIFT_ACCEPT, SHIFT_DECLINE from users
  /// while still processing the JSON in the background
  String _extractUserFriendlyMessage(String content) {
    // List of technical markers with their fallback messages
    final markersWithFallbacks = {
      'AVAILABILITY_MARK': '✅ Your availability has been updated!',
      'SHIFT_ACCEPT': '🎉 Great! You\'ve accepted the shift.',
      'SHIFT_DECLINE': '👍 No problem, the shift has been declined.',
    };

    String cleaned = content;
    String? fallbackMessage;

    // Check if any marker exists in the response
    for (final entry in markersWithFallbacks.entries) {
      final marker = entry.key;
      if (cleaned.contains(marker)) {
        // Extract everything BEFORE the marker (the friendly message)
        final markerIndex = cleaned.indexOf(marker);
        cleaned = cleaned.substring(0, markerIndex).trim();
        fallbackMessage = entry.value;
        break;
      }
    }

    // If the friendly message is empty, use the fallback
    if (cleaned.isEmpty && fallbackMessage != null) {
      return fallbackMessage;
    }

    return cleaned;
  }

  /// Parse AI response for action commands
  void _parseResponseForActions(String content) {
    // Clear previous pending actions
    _pendingAvailability = null;
    _pendingShiftAction = null;

    // Check for AVAILABILITY_MARK
    if (content.contains('AVAILABILITY_MARK')) {
      final start = content.indexOf('{', content.indexOf('AVAILABILITY_MARK'));
      final end = content.lastIndexOf('}');

      if (start != -1 && end != -1 && end > start) {
        try {
          final jsonStr = content.substring(start, end + 1);
          _pendingAvailability = jsonDecode(jsonStr);
          print('[StaffChatService] Availability action parsed: $_pendingAvailability');
        } catch (e) {
          print('[StaffChatService] Failed to parse AVAILABILITY_MARK: $e');
        }
      }
    }

    // Check for SHIFT_ACCEPT
    if (content.contains('SHIFT_ACCEPT')) {
      final start = content.indexOf('{', content.indexOf('SHIFT_ACCEPT'));
      final end = content.lastIndexOf('}');

      if (start != -1 && end != -1 && end > start) {
        try {
          final jsonStr = content.substring(start, end + 1);
          _pendingShiftAction = jsonDecode(jsonStr);
          _pendingShiftAction!['action'] = 'accept';
          print('[StaffChatService] Shift accept action parsed: $_pendingShiftAction');
        } catch (e) {
          print('[StaffChatService] Failed to parse SHIFT_ACCEPT: $e');
        }
      }
    }

    // Check for SHIFT_DECLINE
    if (content.contains('SHIFT_DECLINE')) {
      final start = content.indexOf('{', content.indexOf('SHIFT_DECLINE'));
      final end = content.lastIndexOf('}');

      if (start != -1 && end != -1 && end > start) {
        try {
          final jsonStr = content.substring(start, end + 1);
          _pendingShiftAction = jsonDecode(jsonStr);
          _pendingShiftAction!['action'] = 'decline';
          print('[StaffChatService] Shift decline action parsed: $_pendingShiftAction');
        } catch (e) {
          print('[StaffChatService] Failed to parse SHIFT_DECLINE: $e');
        }
      }
    }
  }

  /// Clear pending availability action
  void clearPendingAvailability() {
    _pendingAvailability = null;
  }

  /// Clear pending shift action
  void clearPendingShiftAction() {
    _pendingShiftAction = null;
  }

  /// Change AI provider
  void setProvider(AIProvider provider) {
    _selectedProvider = provider;
    print('[StaffChatService] AI provider changed to: ${provider.name}');
  }

  /// Clear conversation history
  void clearConversation() {
    _conversationHistory.clear();
    _pendingAvailability = null;
    _pendingShiftAction = null;
    // Reset conversation tracking
    _conversationStartTime = DateTime.now();
    _inputSource = 'text';
    print('[StaffChatService] Conversation cleared');
  }

  /// Set input source for conversation tracking
  void setInputSource(String source) {
    if (source == 'text' || source == 'voice') {
      _inputSource = source;
      print('[StaffChatService] Input source set to: $_inputSource');
    }
  }

  /// Export conversation data for saving to database
  Map<String, dynamic> exportConversationSummary({
    required String outcome,
    String? outcomeReason,
    Map<String, dynamic>? actionData,
  }) {
    final now = DateTime.now();
    final durationMs = _conversationStartTime != null
        ? now.difference(_conversationStartTime!).inMilliseconds
        : 0;

    return {
      'messages': _conversationHistory.map((msg) => {
        'role': msg.role,
        'content': msg.content,
        'timestamp': msg.timestamp.toIso8601String(),
      }).toList(),
      'outcome': outcome,
      'outcomeReason': outcomeReason,
      'durationMs': durationMs,
      'toolsUsed': <String>[],
      'inputSource': _inputSource,
      'aiModel': _aiModel,
      'aiProvider': _aiProvider,
      'conversationStartedAt': _conversationStartTime?.toIso8601String() ?? now.toIso8601String(),
      'conversationEndedAt': now.toIso8601String(),
      'actionData': actionData ?? {},
    };
  }

  /// Refresh staff context (force reload)
  Future<void> refreshContext() async {
    await _loadStaffContext(force: true);
    // Invalidate cached system message since context changed
    _cachedSystemMessage = null;
    _systemMessageBuiltAt = null;
    print('[StaffChatService] Staff context refreshed, cache invalidated');
  }

  /// Add a system message to history (for UI feedback)
  void addSystemMessage(String content) {
    _conversationHistory.add(ChatMessage(
      role: 'system',
      content: content,
    ));
  }
}
