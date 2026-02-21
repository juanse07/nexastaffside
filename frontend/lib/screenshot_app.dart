/// Simplified Staff app shell for screenshot capture mode.
///
/// Skips splash, auth, Firebase, and networking. Renders a minimal
/// 4-tab bottom navigation that mirrors RootPage's layout so
/// screenshots look identical to the real app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'shared/presentation/theme/theme.dart';

/// A minimal Staff app for screenshot capture.
///
/// Differences from [MyApp] + [RootPage]:
/// - No splash screen
/// - No auth check
/// - No Firebase, GeofenceService, socket.io
/// - Renders a 4-tab scaffold matching RootPage's bottom nav
/// - Accepts placeholder child widgets per tab
class ScreenshotStaffApp extends StatelessWidget {
  final Locale locale;
  final List<Widget> tabBodies;
  final List<ScreenshotTab> tabs;
  final int initialTab;

  const ScreenshotStaffApp({
    super.key,
    this.locale = const Locale('en'),
    required this.tabBodies,
    required this.tabs,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowShift Staff',
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,
      home: _ScreenshotStaffHome(
        tabBodies: tabBodies,
        tabs: tabs,
        initialTab: initialTab,
      ),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}

/// Describes a bottom tab for the screenshot shell.
class ScreenshotTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const ScreenshotTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _ScreenshotStaffHome extends StatefulWidget {
  final List<Widget> tabBodies;
  final List<ScreenshotTab> tabs;
  final int initialTab;

  const _ScreenshotStaffHome({
    required this.tabBodies,
    required this.tabs,
    required this.initialTab,
  });

  @override
  State<_ScreenshotStaffHome> createState() => _ScreenshotStaffHomeState();
}

class _ScreenshotStaffHomeState extends State<_ScreenshotStaffHome> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: widget.tabBodies,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(widget.tabs.length, (index) {
                return _buildNavItem(
                  icon: widget.tabs[index].icon,
                  selectedIcon: widget.tabs[index].selectedIcon,
                  label: widget.tabs[index].label,
                  index: index,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? AppColors.techBlue : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.techBlue : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
