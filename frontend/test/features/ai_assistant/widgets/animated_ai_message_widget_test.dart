import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai_assistant/widgets/animated_ai_message_widget.dart';
import 'package:frontend/features/ai_assistant/services/staff_chat_service.dart';

void main() {
  group('AnimatedAiMessageWidget', () {
    late ChatMessage testMessage;

    setUp(() {
      testMessage = ChatMessage(
        role: 'assistant',
        content: 'Hello! This is a test message from AI.',
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );
    });

    testWidgets('should render without animation when showAnimation is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: testMessage,
              showAnimation: false,
            ),
          ),
        ),
      );

      // Should show full content immediately
      expect(find.text(testMessage.content), findsOneWidget);
    });

    testWidgets('should show typing indicator initially when animating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: testMessage,
              showAnimation: true,
            ),
          ),
        ),
      );

      // Pump to build initial state
      await tester.pump();

      // Should not show full content immediately
      expect(find.text(testMessage.content), findsNothing);

      // Fast forward past typing indicator (300ms)
      await tester.pump(const Duration(milliseconds: 350));

      // Typewriter should start - content should be partially visible
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('should display AI avatar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: testMessage,
              showAnimation: false,
            ),
          ),
        ),
      );

      // Check for avatar icon
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('should show timestamp after animation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: testMessage,
              showAnimation: false,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should find timestamp (12:00 format)
      expect(find.text('12:00'), findsOneWidget);
    });

    testWidgets('should render markdown correctly',
        (WidgetTester tester) async {
      final markdownMessage = ChatMessage(
        role: 'assistant',
        content: '**Bold text** and *italic text*',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: markdownMessage,
              showAnimation: false,
            ),
          ),
        ),
      );

      await tester.pump();

      // Markdown library should render the content
      expect(find.textContaining('Bold text'), findsOneWidget);
      expect(find.textContaining('italic text'), findsOneWidget);
    });

    testWidgets('should properly dispose controllers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: testMessage,
              showAnimation: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Remove the widget to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      // Should not throw errors during disposal
      await tester.pumpAndSettle();
    });

    testWidgets('should handle empty message content',
        (WidgetTester tester) async {
      final emptyMessage = ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: emptyMessage,
              showAnimation: false,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should render without errors
      expect(find.byType(AnimatedAiMessageWidget), findsOneWidget);
    });

    testWidgets('should complete typewriter animation',
        (WidgetTester tester) async {
      final shortMessage = ChatMessage(
        role: 'assistant',
        content: 'Hi',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: shortMessage,
              showAnimation: true,
            ),
          ),
        ),
      );

      // Initial build
      await tester.pump();

      // Wait for typing indicator (300ms)
      await tester.pump(const Duration(milliseconds: 350));

      // Wait for typewriter animation to complete (short message, ~50ms)
      await tester.pump(const Duration(milliseconds: 100));

      // Settle all animations
      await tester.pumpAndSettle();

      // Full content should be visible
      expect(find.text(shortMessage.content), findsOneWidget);
    });

    testWidgets('should use FadeTransition and SlideTransition',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedAiMessageWidget(
              message: testMessage,
              showAnimation: false,
            ),
          ),
        ),
      );

      await tester.pump();

      // Check for transition widgets
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(SlideTransition), findsOneWidget);
    });
  });

  group('ChatMessage model', () {
    test('should create message with all fields', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0);
      final message = ChatMessage(
        role: 'assistant',
        content: 'Test content',
        timestamp: timestamp,
        provider: AIProvider.groq,
      );

      expect(message.role, 'assistant');
      expect(message.content, 'Test content');
      expect(message.timestamp, timestamp);
      expect(message.provider, AIProvider.groq);
    });

    test('should auto-generate timestamp if not provided', () {
      final before = DateTime.now();
      final message = ChatMessage(
        role: 'user',
        content: 'Test',
      );
      final after = DateTime.now();

      expect(message.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(message.timestamp.isBefore(after.add(const Duration(seconds: 1))), true);
    });

    test('should convert to JSON correctly', () {
      final message = ChatMessage(
        role: 'user',
        content: 'Hello',
      );

      final json = message.toJson();

      expect(json['role'], 'user');
      expect(json['content'], 'Hello');
      expect(json.containsKey('timestamp'), false); // timestamp not in toJson
    });
  });
}
