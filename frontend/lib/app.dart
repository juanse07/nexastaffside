import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth_service.dart';
import 'pages/staff_onboarding_page.dart';
import 'login_page.dart';
import 'l10n/app_localizations.dart';
import 'shared/presentation/theme/theme.dart';
import 'shared/presentation/splash/splash_screen.dart';

/// The root widget of the FlowShift Staff application.
///
/// Shows a premium splash screen on app launch before transitioning to the main content.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _splashComplete = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _logoutSubscription;

  @override
  void initState() {
    super.initState();
    _logoutSubscription = AuthService.onForcedLogout.listen((_) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _logoutSubscription?.cancel();
    super.dispose();
  }

  static Future<String?> _getToken() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'auth_jwt');
  }

  void _onSplashComplete() {
    setState(() {
      _splashComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'FlowShift Staff',
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
      // Initial route - show splash, then check authentication
      home: _splashComplete
          ? FutureBuilder<String?>(
              future: _getToken(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF212C4A), // navySpaceCadet
                            Color(0xFF1E3A8A), // oceanBlue
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'FlowShift',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final hasToken = snapshot.data != null && snapshot.data!.isNotEmpty;
                return hasToken ? const StaffOnboardingGate() : const LoginPage();
              },
            )
          : Scaffold(
              body: FlowShiftSplashScreen(
                variant: 'STAFF',
                onComplete: _onSplashComplete,
              ),
            ),
    );
  }
}
