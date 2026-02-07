import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/pages/event_detail_page.dart';
import 'package:frontend/l10n/app_localizations.dart';

void main() {
  group('Staff EventDetailPage Widget Tests', () {
    Widget buildScreen(Map<String, dynamic> event) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: EventDetailPage(
          event: event,
          showRespondActions: false,
          acceptedEvents: const [],
          availability: const [],
        ),
      );
    }

    // Note: venue_address is intentionally empty to avoid triggering geocoding
    // platform channels which are not available in widget tests.
    final sampleEvent = {
      'id': '123',
      '_id': '123',
      'client_name': 'Acme Corp',
      'event_name': 'Evening Gala',
      'shift_name': 'Evening Gala',
      'date': '2025-12-20',
      'start_time': '18:00',
      'end_time': '23:00',
      'venue_name': 'Grand Ballroom',
      'venue_address': '',
      'city': 'Denver',
      'state': 'CO',
      'status': 'published',
      'roles': [
        {'role': 'Bartender', 'count': 3},
        {'role': 'Server', 'count': 5},
      ],
      'accepted_staff': [],
      'role_stats': [
        {'role': 'Bartender', 'capacity': 3, 'taken': 0, 'remaining': 3, 'is_full': false},
        {'role': 'Server', 'capacity': 5, 'taken': 0, 'remaining': 5, 'is_full': false},
      ],
    };

    testWidgets('renders Scaffold', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('renders event name', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.textContaining('Evening Gala'), findsWidgets);
    });

    testWidgets('renders venue name', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.textContaining('Grand Ballroom'), findsWidgets);
    });

    testWidgets('renders date information', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      // The date 2025-12-20 should be rendered somewhere
      expect(find.textContaining('Dec'), findsWidgets);
    });

    testWidgets('handles missing optional fields', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      final minimalEvent = {
        'id': '456',
        '_id': '456',
        'venue_address': '',
        'roles': [
          {'role': 'Staff', 'count': 1},
        ],
        'accepted_staff': [],
        'role_stats': [],
        'status': 'published',
      };
      await tester.pumpWidget(buildScreen(minimalEvent));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('is a StatefulWidget', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildScreen(sampleEvent));
      expect(find.byType(EventDetailPage), findsOneWidget);
    });
  });
}
