import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/data_service.dart';
import 'services/notification_service.dart';
import 'services/offline_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: '.env');

  // Initialize offline support
  try {
    await OfflineService.initialize();
    await SyncService.initialize();
    print('[Main] Offline support initialized');
  } catch (e) {
    print('[Main] Failed to initialize offline support: $e');
  }

  // Note: NotificationService will be initialized after login
  // (in staff_onboarding_page.dart after user is authenticated)

  runApp(
    ChangeNotifierProvider(
      create: (context) => DataService()..initialize(),
      child: const MyApp(),
    ),
  );
}
