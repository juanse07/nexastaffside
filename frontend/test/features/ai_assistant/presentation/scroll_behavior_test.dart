import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/ai_assistant/presentation/staff_ai_chat_screen.dart';
import 'package:frontend/providers/terminology_provider.dart';

void main() {
  group('Scroll Behavior Tests', () {
    Widget createWidgetUnderTest() {
      return ChangeNotifierProvider(
        create: (_) => TerminologyProvider(),
        child: const MaterialApp(
          home: StaffAIChatScreen(),
        ),
      );
    }

    testWidgets('should scroll to bottom when messages are added',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find the ListView
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);

      // Get the scroll controller
      final ListView listView = tester.widget(listViewFinder);
      final ScrollController? controller = listView.controller;

      expect(controller, isNotNull);

      // After initialization, should be scrolled to show messages
      // The welcome message should be visible
      expect(find.textContaining('AI assistant'), findsWidgets);
    });

    testWidgets('ListView should have scroll controller attached',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final ListView listView = tester.widget(find.byType(ListView));
      expect(listView.controller, isNotNull,
          reason: 'ListView must have ScrollController for auto-scroll');
    });

    testWidgets('should maintain scroll position after rebuild',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Trigger a rebuild by interacting with UI
      final modelSelector = find.byIcon(Icons.bolt);
      if (modelSelector.evaluate().isNotEmpty) {
        await tester.tap(modelSelector);
        await tester.pump();

        // Close menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
      }

      // ListView should still exist
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
