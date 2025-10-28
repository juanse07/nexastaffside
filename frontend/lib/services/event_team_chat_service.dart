import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/event_chat_message.dart';

class EventTeamChatService extends ChangeNotifier {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  final StreamController<EventChatMessage> _messageStreamController =
      StreamController<EventChatMessage>.broadcast();

  Stream<EventChatMessage> get messageStream => _messageStreamController.stream;

  static String get _apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    if (!kIsWeb && Platform.isAndroid) {
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

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Fetch messages for an event
  Future<List<EventChatMessage>> fetchMessages(String eventId, {int limit = 50, String? before}) async {
    try {
      final headers = await _getHeaders();
      var url = Uri.parse('$_apiBaseUrl$_apiPathPrefix/api/events/$eventId/chat/messages?limit=$limit');

      if (before != null && before.isNotEmpty) {
        url = Uri.parse('$_apiBaseUrl$_apiPathPrefix/api/events/$eventId/chat/messages?limit=$limit&before=$before');
      }

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messages = (data['messages'] as List<dynamic>)
            .map((json) => EventChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        debugPrint('[EventTeamChat] Fetched ${messages.length} messages for event $eventId');
        return messages;
      } else {
        final errorBody = json.decode(response.body) as Map<String, dynamic>?;
        throw Exception(errorBody?['message'] ?? 'Failed to fetch messages');
      }
    } catch (e) {
      debugPrint('[EventTeamChat] Error fetching messages: $e');
      rethrow;
    }
  }

  /// Send a message to the event team chat
  Future<EventChatMessage> sendMessage(String eventId, String message) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_apiBaseUrl$_apiPathPrefix/api/events/$eventId/chat/messages');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'message': message}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final sentMessage = EventChatMessage.fromJson(data['message'] as Map<String, dynamic>);

        debugPrint('[EventTeamChat] Message sent successfully: ${sentMessage.id}');
        return sentMessage;
      } else {
        final errorBody = json.decode(response.body) as Map<String, dynamic>?;
        throw Exception(errorBody?['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      debugPrint('[EventTeamChat] Error sending message: $e');
      rethrow;
    }
  }

  /// Handle incoming Socket.IO message
  void handleSocketMessage(Map<String, dynamic> data) {
    try {
      final messageData = data['message'] as Map<String, dynamic>?;
      if (messageData != null) {
        final message = EventChatMessage.fromJson(messageData);
        _messageStreamController.add(message);
        debugPrint('[EventTeamChat] Received socket message: ${message.id}');
      }
    } catch (e) {
      debugPrint('[EventTeamChat] Error handling socket message: $e');
    }
  }

  @override
  void dispose() {
    _messageStreamController.close();
    super.dispose();
  }
}
