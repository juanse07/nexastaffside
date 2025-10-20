import 'package:flutter/material.dart';

import 'pages/staff_onboarding_page.dart';
import 'login_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexa Staff',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF6366F1), // Primary indigo
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF430172), // Deep purple
          onPrimaryContainer: Colors.white,
          secondary: const Color(0xFF8B5CF6), // Secondary purple
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFF8B5CF6),
          onSecondaryContainer: Colors.white,
          surface: const Color(0xFFFAFAFC),
          onSurface: const Color(0xFF0F172A),
          surfaceContainerLowest: const Color(0xFFFFFFFF),
          onSurfaceVariant: const Color(0xFF475569),
          outline: const Color(0xFFE2E8F0),
          outlineVariant: const Color(0xFFF1F5F9),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFF430172),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      routes: {
        '/': (_) => const StaffOnboardingGate(),
        '/login': (_) => const LoginPage(),
      },
      initialRoute: '/',
    );
  }
}
