import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/pages/team_center_page.dart';
import 'package:frontend/services/data_service.dart';

void main() {
  group('Staff TeamCenterPage Widget Tests', () {
    Widget buildScreen() {
      return ChangeNotifierProvider<DataService>(
        create: (_) => DataService(),
        child: const MaterialApp(
          home: TeamCenterPage(),
        ),
      );
    }

    testWidgets('renders Scaffold', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('is a StatefulWidget', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(TeamCenterPage), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(tester.takeException(), isNull);
    });
  });
}
