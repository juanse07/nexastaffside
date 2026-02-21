/// Screenshot-mode entry point for FlowShift Staff.
///
/// Usage:
///   flutter test integration_test/screenshots/screenshot_test.dart \
///     -d <device_id>
///
/// This entry point:
/// - Skips Firebase, dotenv, OfflineService, SyncService
/// - Uses ScreenshotStaffApp with mock tab content
/// - No real networking or auth
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/screenshot_app.dart';

/// Builds the screenshot-mode Staff app.
///
/// Called from the integration test before `pumpWidget`.
Future<Widget> buildScreenshotStaffApp({
  Locale locale = const Locale('en'),
  int initialTab = 0,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Screenshot mode error (suppressed): ${details.exception}');
  };

  return ScreenshotStaffApp(
    locale: locale,
    initialTab: initialTab,
    tabs: const [
      ScreenshotTab(
        icon: Icons.work_outline_rounded,
        selectedIcon: Icons.work_rounded,
        label: 'Shifts',
      ),
      ScreenshotTab(
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
        label: 'Chats',
      ),
      ScreenshotTab(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        label: 'Earnings',
      ),
      ScreenshotTab(
        icon: Icons.access_time_outlined,
        selectedIcon: Icons.access_time,
        label: 'Clock In',
      ),
    ],
    tabBodies: [
      _PlaceholderTab(title: 'Available Shifts', icon: Icons.work_rounded),
      _PlaceholderTab(title: 'Conversations', icon: Icons.chat_bubble),
      _PlaceholderTab(title: 'Earnings', icon: Icons.account_balance_wallet),
      _PlaceholderTab(title: 'Clock In', icon: Icons.access_time),
    ],
  );
}

/// Placeholder tab body for when real screens aren't available.
class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
