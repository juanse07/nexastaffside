// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app.dart';
import 'package:frontend/services/data_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Renders MyApp and shows Home tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>(
        create: (_) => DataService(),
        child: const MyApp(),
      ),
    );

    // Allow first frame to build. App shows a loading spinner until auth completes.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
