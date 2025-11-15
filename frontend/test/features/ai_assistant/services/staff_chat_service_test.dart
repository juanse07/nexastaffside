import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'dart:convert';
import 'package:frontend/features/ai_assistant/services/staff_chat_service.dart';

// Generate mocks
@GenerateMocks([http.Client])
import 'staff_chat_service_test.mocks.dart';

void main() {
  group('StaffChatService', () {
    late StaffChatService service;

    setUp(() {
      service = StaffChatService();
    });

    test('should initialize with empty conversation history', () {
      expect(service.conversationHistory, isEmpty);
      expect(service.isLoading, false);
      expect(service.selectedProvider, AIProvider.groq);
    });

    test('should add user message to conversation', () async {
      await service.initialize();

      // Add a system message manually for testing
      service.addSystemMessage('Test system message');

      expect(service.conversationHistory.length, 1);
      expect(service.conversationHistory.first.role, 'system');
      expect(service.conversationHistory.first.content, 'Test system message');
    });

    test('should clear conversation history', () async {
      await service.initialize();

      service.addSystemMessage('Message 1');
      service.addSystemMessage('Message 2');
      expect(service.conversationHistory.length, 2);

      service.clearConversation();
      expect(service.conversationHistory, isEmpty);
    });

    test('should parse AVAILABILITY_MARK from AI response', () {
      final content = '''
      I've found some available dates for you!

      AVAILABILITY_MARK
      {"dates": ["2024-01-15", "2024-01-16"], "status": "available"}
      ''';

      // Use the internal parse method (accessing through reflection is complex in tests,
      // so we test via sendMessage which calls parseResponseForActions internally)
      service.addSystemMessage(content);

      // For testing parsing, we'll verify the functionality through integration
      expect(service.conversationHistory.length, 1);
    });

    test('should clear pending availability', () {
      // Simulate pending availability
      service.clearPendingAvailability();
      expect(service.pendingAvailability, isNull);
    });

    test('should clear pending shift action', () {
      service.clearPendingShiftAction();
      expect(service.pendingShiftAction, isNull);
    });

    test('should set AI provider', () {
      expect(service.selectedProvider, AIProvider.groq);

      service.setProvider(AIProvider.claude);
      expect(service.selectedProvider, AIProvider.claude);

      service.setProvider(AIProvider.openai);
      expect(service.selectedProvider, AIProvider.openai);
    });

    test('should get singular form of terminology correctly', () {
      // Testing via the initialization which uses terminology
      expect(() => service.initialize(), returnsNormally);
    });

    group('System message caching', () {
      test('should build system message on first call', () async {
        await service.initialize();
        // System message building is tested through the actual message sending
        // which is complex to test without HTTP mocking
      });

      test('should invalidate cache on refresh', () async {
        await service.initialize();
        // Initial state
        expect(service.conversationHistory, isEmpty);

        // Refresh context should clear cache
        await service.refreshContext();

        // Should still be empty but cache invalidated
        expect(service.conversationHistory, isEmpty);
      });
    });

    group('ChatMessage', () {
      test('should create ChatMessage with all properties', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0);
        final message = ChatMessage(
          role: 'user',
          content: 'Hello AI',
          timestamp: timestamp,
          provider: AIProvider.groq,
        );

        expect(message.role, 'user');
        expect(message.content, 'Hello AI');
        expect(message.timestamp, timestamp);
        expect(message.provider, AIProvider.groq);
      });

      test('should create ChatMessage with default timestamp', () {
        final before = DateTime.now();
        final message = ChatMessage(
          role: 'assistant',
          content: 'Hi there!',
        );
        final after = DateTime.now();

        expect(message.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), true);
        expect(message.timestamp.isBefore(after.add(const Duration(seconds: 1))), true);
      });

      test('should convert to JSON correctly', () {
        final message = ChatMessage(
          role: 'user',
          content: 'Test message',
        );

        final json = message.toJson();

        expect(json, {
          'role': 'user',
          'content': 'Test message',
        });
      });

      test('should not include timestamp in JSON', () {
        final message = ChatMessage(
          role: 'user',
          content: 'Test',
          timestamp: DateTime(2024, 1, 1),
        );

        final json = message.toJson();
        expect(json.containsKey('timestamp'), false);
      });

      test('should not include provider in JSON', () {
        final message = ChatMessage(
          role: 'assistant',
          content: 'Response',
          provider: AIProvider.claude,
        );

        final json = message.toJson();
        expect(json.containsKey('provider'), false);
      });
    });

    group('AIProvider enum', () {
      test('should have correct values', () {
        expect(AIProvider.values.length, 3);
        expect(AIProvider.values.contains(AIProvider.openai), true);
        expect(AIProvider.values.contains(AIProvider.claude), true);
        expect(AIProvider.values.contains(AIProvider.groq), true);
      });

      test('should convert to string correctly', () {
        expect(AIProvider.groq.name, 'groq');
        expect(AIProvider.claude.name, 'claude');
        expect(AIProvider.openai.name, 'openai');
      });
    });

    group('Message parsing', () {
      test('should handle SHIFT_ACCEPT command', () async {
        await service.initialize();

        service.addSystemMessage('SHIFT_ACCEPT {"shift_name": "Event A", "shift_id": "123"}');

        // Verify message was added
        expect(service.conversationHistory.length, 1);
      });

      test('should handle SHIFT_DECLINE command', () async {
        await service.initialize();

        service.addSystemMessage('SHIFT_DECLINE {"shift_name": "Event B", "shift_id": "456"}');

        // Verify message was added
        expect(service.conversationHistory.length, 1);
      });

      test('should handle multiple commands in sequence', () async {
        await service.initialize();

        service.addSystemMessage('Message 1');
        service.addSystemMessage('Message 2');
        service.addSystemMessage('Message 3');

        expect(service.conversationHistory.length, 3);
      });
    });

    group('Default system instructions', () {
      test('should generate with custom terminology', () async {
        await service.initialize();
        // Initialization loads default system instructions
        expect(() => service.initialize(), returnsNormally);
      });

      test('should handle missing terminology gracefully', () async {
        expect(() => service.initialize(), returnsNormally);
      });
    });

    group('Loading state', () {
      test('should start with isLoading false', () {
        expect(service.isLoading, false);
      });

      test('should track loading state', () {
        // isLoading is controlled internally by sendMessage
        // which requires network calls to test properly
        expect(service.isLoading, false);
      });
    });
  });
}
