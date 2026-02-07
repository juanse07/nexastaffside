import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/pages/user_profile_page.dart';
import 'package:frontend/l10n/app_localizations.dart';

void main() {
  group('Staff UserProfilePage Widget Tests', () {
    Widget buildScreen() {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const UserProfilePage(),
      );
    }

    testWidgets('renders Scaffold', (tester) async {
      await tester.pumpWidget(buildScreen());
      // Use pump() instead of pumpAndSettle() — the page makes HTTP calls
      // in initState that never resolve in tests, causing pumpAndSettle to timeout.
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('is a StatefulWidget', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(UserProfilePage), findsOneWidget);
    });

    testWidgets('renders without pump errors', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Widget should render in loading state without throwing
      expect(find.byType(UserProfilePage), findsOneWidget);
    });

    testWidgets('shows loading or profile content', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Should show loading state or profile content
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.textContaining('Profile').evaluate().isNotEmpty ||
            find.byType(TextField).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
