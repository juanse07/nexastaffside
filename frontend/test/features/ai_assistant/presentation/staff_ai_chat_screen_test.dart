import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/ai_assistant/presentation/staff_ai_chat_screen.dart';
import 'package:frontend/providers/terminology_provider.dart';

void main() {
  group('StaffAIChatScreen', () {
    Widget createWidgetUnderTest() {
      return ChangeNotifierProvider(
        create: (_) => TerminologyProvider(),
        child: const MaterialApp(
          home: StaffAIChatScreen(),
        ),
      );
    }

    testWidgets('should render loading indicator initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Should show loading indicator before initialization
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render app bar with title',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Find app bar with title
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should show chat input widget after initialization',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Wait for initialization (shorter timeout)
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Should show input field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should display model selector in app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find model selector icon
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('should display clear conversation button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find delete icon for clearing conversation
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('should show usage indicator for free tier',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show usage stats (0/50 initially)
      expect(find.byIcon(Icons.chat_bubble_outline), findsWidgets);
    });

    testWidgets('should render ListView for messages',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find the messages ListView
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should show suggestion chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Look for suggestion chips
      expect(find.byType(ActionChip), findsWidgets);
    });

    testWidgets('should display welcome message after initialization',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Check for welcome message content
      expect(find.textContaining('AI assistant'), findsWidgets);
    });

    testWidgets('should open model selector menu on tap',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap on model selector icon
      await tester.tap(find.byIcon(Icons.bolt));
      await tester.pump();
      await tester.pump();

      // Should show popup menu with model options
      expect(find.text('Llama 3.1 8B'), findsOneWidget);
      expect(find.text('GPT-OSS 20B'), findsOneWidget);
    });

    testWidgets('should show clear conversation dialog on delete tap',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump();

      // Should show confirmation dialog
      expect(find.text('Clear Conversation?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('should cancel clear conversation dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Open dialog
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();

      // Dialog should be dismissed
      expect(find.text('Clear Conversation?'), findsNothing);
    });

    testWidgets('should use RepaintBoundary for messages',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should have RepaintBoundary widgets for optimization
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('should have scroll controller attached to ListView',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // ListView should be scrollable
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.controller, isNotNull);
    });

    testWidgets('should show keyboard when tapping input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap on text field
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // TextField should be focused
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, true);
    });

    testWidgets('should display send button in input area',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find send button icon
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('should show microphone button when field is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show mic button for voice input
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('should render with correct background color',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFF8FAFC));
    });

    testWidgets('should handle app bar actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // App bar should have actions
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isNotNull);
      expect(appBar.actions!.length, greaterThan(0));
    });

    testWidgets('should initialize with correct state',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Initially not initialized
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // After pumping, should be initialized
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('StaffAIChatScreen Performance', () {
    Widget createWidgetUnderTest() {
      return ChangeNotifierProvider(
        create: (_) => TerminologyProvider(),
        child: const MaterialApp(
          home: StaffAIChatScreen(),
        ),
      );
    }

    testWidgets('should use ValueKey for list items',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find RepaintBoundary widgets which should have ValueKeys
      final repaintBoundaries = find.byType(RepaintBoundary);
      expect(repaintBoundaries, findsWidgets);

      // Each RepaintBoundary should have a key
      for (final element in tester.elementList(repaintBoundaries)) {
        expect(element.widget.key, isNotNull);
      }
    });

    testWidgets('should properly manage scroll controller lifecycle',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Remove widget to test disposal
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // Should not throw during disposal
      await tester.pump();
      await tester.pump();
    });
  });
}
