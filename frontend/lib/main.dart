import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
// TODO: Re-enable Firebase when GoogleService-Info.plist is configured
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'app.dart';
import 'services/data_service.dart';
import 'services/offline_service.dart';
import 'services/sync_service.dart';
import 'providers/terminology_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Re-enable Firebase/Crashlytics when GoogleService-Info.plist is configured
  // await Firebase.initializeApp();
  // FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // PlatformDispatcher.instance.onError = (error, stack) {
  //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  //   return true;
  // };

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
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => DataService()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => TerminologyProvider()..initialize(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
