import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../auth_service.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'data_service.dart';

class ChatService extends ChangeNotifier {
  factory ChatService() => _instance;
  ChatService._internal() {
    _setupSocketListeners();
  }

  static final ChatService _instance = ChatService._internal();

  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  void _setupSocketListeners() {
    // Listen to socket events from DataService
    DataService().addListener(_handleDataServiceUpdate);
  }

  void _handleDataServiceUpdate() {
    // This will be called when DataService updates
    // We can add custom logic here if needed
  }

  static String get _apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    // Handle Android emulator
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (raw.contains('127.0.0.1')) {
        return raw.replaceAll('127.0.0.1', '10.0.2.2');
      }
      if (raw.contains('localhost')) {
        return raw.replaceAll('localhost', '10.0.2.2');
      }
    }
    return raw;
  }

  static String get _apiPathPrefix {
    final raw = (dotenv.env['API_PATH_PREFIX'] ?? '').trim();
    if (raw.isEmpty) return '';
    final withLead = raw.startsWith('/') ? raw : '/$raw';
    return withLead.endsWith('/')
        ? withLead.substring(0, withLead.length - 1)
        : withLead;
  }

  Future<List<Conversation>> fetchConversations() async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse('$_apiBaseUrl${_apiPathPrefix}/chat/conversations');

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      debugPrint('[CHAT DEBUG] Received conversations: ${data['conversations']}');
      final conversations = (data['conversations'] as List<dynamic>)
          .map((e) {
            final conv = Conversation.fromJson(e as Map<String, dynamic>);
            debugPrint('[CHAT DEBUG] Conversation parsed - ID: ${conv.id}, ManagerID: ${conv.managerId}');
            return conv;
          })
          .toList();
      return conversations;
    } else {
      throw Exception('Failed to fetch conversations: ${response.body}');
    }
  }

  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  }) async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (before != null) 'before': before.toIso8601String(),
    };

    final url = Uri.parse(
      '$_apiBaseUrl${_apiPathPrefix}/chat/conversations/$conversationId/messages',
    ).replace(queryParameters: queryParams);

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return messages;
    } else {
      throw Exception('Failed to fetch messages: ${response.body}');
    }
  }

  Future<ChatMessage> sendMessage(String managerId, String message) async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    debugPrint('[CHAT DEBUG] Sending message to managerId: $managerId');
    debugPrint('[CHAT DEBUG] Manager ID length: ${managerId.length}');
    debugPrint('[CHAT DEBUG] Manager ID type: ${managerId.runtimeType}');

    final url = Uri.parse(
      '$_apiBaseUrl${_apiPathPrefix}/chat/conversations/$managerId/messages',
    );

    debugPrint('[CHAT DEBUG] Request URL: $url');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(<String, dynamic>{
        'message': message,
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final newMessage =
          ChatMessage.fromJson(data['message'] as Map<String, dynamic>);

      // Emit to local stream for real-time update
      _messageController.add(newMessage);

      return newMessage;
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  Future<void> markAsRead(String conversationId) async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse(
      '$_apiBaseUrl${_apiPathPrefix}/chat/conversations/$conversationId/read',
    );

    final response = await http.patch(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark as read: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchManagers() async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse('$_apiBaseUrl${_apiPathPrefix}/chat/managers');

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['managers'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch managers: ${response.body}');
    }
  }

  /// Respond to an event invitation (accept or decline)
  Future<void> respondToInvitation({
    required String messageId,
    required String eventId,
    required String roleId,
    required bool accept,
  }) async {
    debugPrint('[ChatService] respondToInvitation called. messageId: $messageId, accept: $accept');

    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse(
      '$_apiBaseUrl${_apiPathPrefix}/chat/invitations/$messageId/respond',
    );

    final response = await http.post(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(<String, dynamic>{
        'accept': accept,
        'eventId': eventId,
        'roleId': roleId,
      }),
    );

    debugPrint('[ChatService] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to respond to invitation: ${response.body}');
    }
  }

  /// Fetch event details for an invitation by message ID
  /// This uses a dedicated endpoint that bypasses normal event visibility rules
  Future<Map<String, dynamic>> fetchInvitationEvent(String messageId) async {
    debugPrint('[ChatService] fetchInvitationEvent called for messageId: $messageId');

    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse('$_apiBaseUrl${_apiPathPrefix}/chat/invitations/$messageId/event');

    debugPrint('[ChatService] Fetching invitation event from: $url');

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('[ChatService] Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      debugPrint('[ChatService] Successfully fetched event: ${data['title'] ?? data['event_name']}');
      return data;
    } else {
      debugPrint('[ChatService] Failed to fetch invitation event: ${response.body}');
      throw Exception('Failed to fetch invitation event: ${response.body}');
    }
  }

  void sendTypingIndicator(
    String conversationId,
    bool isTyping,
    SenderType senderType,
  ) {
    // Get socket from DataService
    final dataService = DataService();
    // Socket.IO typing indicator would be sent here if socket is exposed
    // For now, we'll skip this as it requires modifying DataService
  }

  void handleIncomingMessage(Map<String, dynamic> messageData) {
    try {
      final message = ChatMessage.fromJson(messageData);
      _messageController.add(message);
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing incoming chat message: $e');
    }
  }

  @override
  void dispose() {
    _messageController.close();
    _typingController.close();
    super.dispose();
  }
}
