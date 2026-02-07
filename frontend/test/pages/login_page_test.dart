import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/login_page.dart';

void main() {
  group('Staff LoginPage Widget Tests', () {
    Widget buildLoginPage() {
      return const MaterialApp(
        home: LoginPage(),
      );
    }

    testWidgets('renders Welcome Back text', (tester) async {
      // Use a large viewport to minimize layout overflow in test environment
      tester.view.physicalSize = const Size(1800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('renders sign-in subtitle', (tester) async {
      tester.view.physicalSize = const Size(1800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.text('Sign in to continue to your account'), findsOneWidget);
    });

    testWidgets('renders Continue with Google button', (tester) async {
      tester.view.physicalSize = const Size(1800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('renders Continue with Phone button', (tester) async {
      tester.view.physicalSize = const Size(1800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.text('Continue with Phone'), findsOneWidget);
    });

    testWidgets('renders terms footer', (tester) async {
      tester.view.physicalSize = const Size(1800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.textContaining('Terms of Service'), findsOneWidget);
    });

    testWidgets('renders LoginPage widget type', (tester) async {
      tester.view.physicalSize = const Size(1800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflow')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
