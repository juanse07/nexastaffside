import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/staff_onboarding_page.dart';
import 'login_page.dart';
import 'l10n/app_localizations.dart';
import 'shared/presentation/theme/theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static Future<String?> _getToken() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'auth_jwt');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tie Staff',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('es'), // Spanish
      ],
      // Light theme (default)
      theme: AppTheme.lightTheme(),
      // Dark theme
      darkTheme: AppTheme.darkTheme(),
      // Force light mode
      themeMode: ThemeMode.light,
      routes: {
        '/login': (_) => const LoginPage(),
      },
      home: FutureBuilder<String?>(
        future: _getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final hasToken = snapshot.data != null && snapshot.data!.isNotEmpty;
          return hasToken ? const StaffOnboardingGate() : const LoginPage();
        },
      ),
    );
  }
}
