import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../auth_service.dart';
import '../login_page.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';
import '../services/offline_service.dart';
import '../services/sync_service.dart';
import '../services/geofence_service.dart';
import '../providers/terminology_provider.dart';
import '../models/pending_clock_action.dart';
import '../utils/id.dart';
import '../utils/jwt.dart';
import '../utils/accepted_staff.dart';
import '../widgets/enhanced_refresh_indicator.dart';
import 'event_detail_page.dart';
import 'past_events_page.dart';
import 'user_profile_page.dart';
import 'team_center_page.dart';
import 'earnings_page.dart';
import 'conversations_page.dart';
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';
import '../features/ai_assistant/presentation/staff_ai_chat_screen.dart';
import '../core/navigation/route_error_manager.dart';
import '../services/subscription_service.dart';
import '../shared/widgets/free_month_banner.dart';
import '../shared/widgets/subscription_gate.dart';

enum _AccountMenuAction { profile, teams, logout }

List<Uri> _mapUriCandidates(String raw) {
  final trimmed = raw.trim();
  final List<Uri> candidates = [];

  void addUri(String value) {
    try {
      final u = Uri.parse(value);
      if (!candidates.any((e) => e.toString() == u.toString())) {
        candidates.add(u);
      }
    } catch (_) {}
  }

  if (trimmed.isEmpty) return candidates;

  // 1) If already a full URI
  try {
    final direct = Uri.parse(trimmed);
    if (direct.hasScheme) {
      candidates.add(direct);
    }
  } catch (_) {}

  // 2) Prepend https:// for common host-only inputs
  final looksLikeHost =
      trimmed.startsWith('www.') ||
      trimmed.startsWith('maps.google.') ||
      trimmed.startsWith('google.') ||
      trimmed.startsWith('goo.gl/');
  if (!trimmed.contains('://') && looksLikeHost) {
    addUri('https://$trimmed');
  }

  // 3) Lat/Lng pair
  final latLng = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\s*$',
  ).firstMatch(trimmed);
  if (latLng != null) {
    final lat = latLng.group(1);
    final lng = latLng.group(2);
    if (lat != null && lng != null) {
      // Android geo: scheme
      addUri('geo:$lat,$lng?q=$lat,$lng');
      // Google navigation intent
      addUri('google.navigation:q=$lat,$lng');
      // Google Maps app scheme (if installed)
      addUri('comgooglemaps://?q=$lat,$lng');
      addUri('comgooglemaps://?daddr=$lat,$lng');
      // Web/http fallback
      addUri('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      // Directions deep link
      addUri('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    }
  } else {
    // 4) Treat as search query (address/place name)
    final q = Uri.encodeComponent(trimmed);
    // Android geo: query
    addUri('geo:0,0?q=$q');
    // Google navigation intent
    addUri('google.navigation:q=$q');
    // Google Maps app scheme (if installed)
    addUri('comgooglemaps://?q=$q');
    // Web/http fallback
    addUri('https://www.google.com/maps/search/?api=1&query=$q');
    // Directions deep link
    addUri('https://www.google.com/maps/dir/?api=1&destination=$q');
  }

  return candidates;
}

Future<void> _launchMapUrl(String url) async {
  try {
    print('Attempting to launch map for: "$url"');
    final candidates = _mapUriCandidates(url);
    // On Android, some resolve checks may fail due to package visibility.
    // Try launching directly and fall back on errors.
    for (final uri in candidates) {
      print('Trying URI: ${uri.toString()}');
      try {
        // Prefer direct launch on Android.
        if (Platform.isAndroid) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) {
            print('Launched: ${uri.toString()}');
            return;
          }
        } else {
          if (await canLaunchUrl(uri)) {
            final ok = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (ok) {
              print('Launched: ${uri.toString()}');
              return;
            }
          }
        }
      } catch (e) {
        print('Launch failed for ${uri.toString()}: $e');
      }
    }
    throw 'Could not launch map';
  } catch (e) {
    print('Error launching map: $e');
  }
}

// Format date/time like: "Tue. Sep 2 • 5:00 PM — 11:55 PM MDT"
String _formatEventDateTimeLabel({
  required String? dateStr,
  required String? startTimeStr,
  required String? endTimeStr,
}) {
  DateTime? parseDateSafe(String input) {
    try {
      final iso = DateTime.tryParse(input);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    } catch (_) {}
    final us = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$').firstMatch(input);
    if (us != null) {
      final m = int.tryParse(us.group(1) ?? '');
      final d = int.tryParse(us.group(2) ?? '');
      var y = int.tryParse(us.group(3) ?? '');
      if (m != null && d != null && y != null) {
        if (y < 100) y += 2000;
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    final eu = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$').firstMatch(input);
    if (eu != null) {
      final a = int.tryParse(eu.group(1) ?? '');
      final b = int.tryParse(eu.group(2) ?? '');
      var y = int.tryParse(eu.group(3) ?? '');
      if (a != null && b != null && y != null) {
        if (a > 12 && b >= 1 && b <= 12) {
          if (y < 100) y += 2000;
          if (a >= 1 && a <= 31) {
            return DateTime(y, b, a);
          }
        }
      }
    }
    final ymd = RegExp(
      r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$',
    ).firstMatch(input);
    if (ymd != null) {
      final y = int.tryParse(ymd.group(1) ?? '');
      final m = int.tryParse(ymd.group(2) ?? '');
      final d = int.tryParse(ymd.group(3) ?? '');
      if (y != null && m != null && d != null) {
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    return null;
  }

  (int, int)? tryParseTimeOfDay(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final reg = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$');
    final m = reg.firstMatch(s);
    if (m == null) return null;
    int hour = int.tryParse(m.group(1) ?? '') ?? 0;
    int minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ampm = m.group(3);
    if (ampm != null) {
      final upper = ampm.toUpperCase();
      if (upper == 'AM') {
        if (hour == 12) hour = 0;
      } else if (upper == 'PM') {
        if (hour != 12) hour += 12;
      }
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  String weekdayShort(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${names[(weekday - 1).clamp(0, 6)]}.';
  }

  String monthShort(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  String formatTime(int h24, int m) {
    final isPm = h24 >= 12;
    int h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h12:$mm ${isPm ? 'PM' : 'AM'}';
  }

  final tz = DateTime.now().timeZoneName;
  final date = (dateStr == null || dateStr.trim().isEmpty)
      ? null
      : parseDateSafe(dateStr.trim());
  final start = tryParseTimeOfDay(startTimeStr);
  final end = tryParseTimeOfDay(endTimeStr);

  if (date == null) return '';
  final left =
      '${date.day} ${monthShort(date.month)}'; // Changed format to "3 Nov"
  String right = '';
  if (start != null && end != null) {
    right =
        '${formatTime(start.$1, start.$2)} — ${formatTime(end.$1, end.$2)} $tz';
  } else if (start != null) {
    right = '${formatTime(start.$1, start.$2)} $tz';
  }
  return right.isEmpty ? left : '$left • $right';
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with TickerProviderStateMixin {
  bool _checkingAuth = true;
  String? _userKey;
  String? _userPictureUrl;
  int _selectedBottomIndex = 0;
  Map<String, dynamic>? _upcoming;

  // Bottom bar visibility - Optimized for performance
  bool _isBottomBarVisible = true;
  bool _showAskLabel = true; // Collapses to icon-only on scroll
  late AnimationController _bottomBarAnimationController;
  late Animation<Offset> _bottomBarAnimation;
  final GlobalKey _bottomBarKey = GlobalKey();
  double _bottomBarHeight = 0;

  // Performance optimizations
  Timer? _scrollEndTimer;
  bool _isAnimating = false;

  // For scroll detection - Optimized thresholds
  double _lastScrollPosition = 0;
  double _scrollThreshold = 3.0; // Reduced for faster response
  double _velocityThreshold = 120.0; // Velocity-based hiding
  double _lastVelocity = 0;

  // Notifier to tell _RolesSection to switch to My Shifts
  final ValueNotifier<int> _resetToMyShifts = ValueNotifier<int>(0);

  void _goToMyShifts() {
    setState(() => _selectedBottomIndex = 0);
    _resetToMyShifts.value++; // Trigger listener in _RolesSection
    _showBottomBar();
  }

  // Geofencing for auto clock-in
  final GeofenceService _geofenceService = GeofenceService();
  StreamSubscription<String>? _autoClockInSubscription;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
    _loadDefaultTab();

    // Initialize bottom bar animation - Optimized for performance
    _bottomBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomBarAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _bottomBarAnimationController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    ));

    // Initialize geofence service for auto clock-in
    _initializeGeofenceService();
  }

  Future<void> _initializeGeofenceService() async {
    try {
      await _geofenceService.initialize();

      // Listen for auto clock-in events
      _autoClockInSubscription = _geofenceService.onAutoClockIn.listen((eventId) {
        debugPrint('Auto clocked in to event: $eventId');
        // Refresh data to show updated clock-in status
        if (mounted) {
          context.read<DataService>().loadInitialData();
        }
      });

      // Listen to data service events and register geofences
      context.read<DataService>().addListener(_updateGeofences);
    } catch (e) {
      debugPrint('Error initializing geofence service: $e');
    }
  }

  void _updateGeofences() {
    final dataService = context.read<DataService>();
    final events = dataService.events;

    // Filter for accepted events only
    if (_userKey != null && events.isNotEmpty) {
      final acceptedEvents = events.where((e) {
        final accepted = e['accepted_staff'];
        if (accepted is List) {
          return accepted.any((a) {
            if (a is String) return a == _userKey;
            if (a is Map) return a['userKey'] == _userKey;
            return false;
          });
        }
        return false;
      }).toList();

      // Register geofences for accepted events
      _geofenceService.registerEventGeofences(acceptedEvents);
    }
  }

  Future<void> _loadDefaultTab() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultTab = prefs.getInt('default_tab') ?? 0;
    if (mounted) {
      setState(() {
        _selectedBottomIndex = defaultTab;
      });
    }
  }

  Future<void> _ensureSignedIn() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null && mounted) {
        await RouteErrorManager.instance.pushNamedSafely(context, '/login');
        return;
      }
      final newToken = await AuthService.getJwt();
      _userKey = newToken == null ? null : decodeUserKeyFromJwt(newToken);
      if (mounted) {
        setState(() => _checkingAuth = false);
      }
    } catch (e) {
      // Handle secure storage corruption by clearing it and redirecting to login
      print('Secure storage error: $e');
      await AuthService.signOut(); // This will clear the corrupted storage
      if (mounted) {
        await RouteErrorManager.instance.pushNamedSafely(context, '/login');
      }
    }

    // Load initial data using DataService
    if (mounted) {
      context.read<DataService>().loadInitialData();
    }

    // Load subscription status (for free month banner / read-only gating)
    unawaited(_loadSubscriptionStatus());

    // Load user profile (for avatar)
    unawaited(_loadUserProfile());
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      await SubscriptionService().getBackendStatus();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading subscription status: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final me = await UserService.getMe();
      if (!mounted) return;
      setState(() {
        _userPictureUrl = (me.picture ?? '').trim().isEmpty
            ? null
            : me.picture!.trim();
      });
    } catch (_) {
      // Ignore errors loading profile for avatar
    }
  }

  @override
  void dispose() {
    _scrollEndTimer?.cancel();
    _bottomBarAnimationController.dispose();
    _autoClockInSubscription?.cancel();
    _geofenceService.stopMonitoring();
    super.dispose();
  }

  void _hideBottomBar() {
    if (_isBottomBarVisible && !_isAnimating) {
      _isAnimating = true;
      _isBottomBarVisible = false;
      _bottomBarAnimationController.forward().whenComplete(() {
        _isAnimating = false;
      });
    }
    if (_showAskLabel) setState(() => _showAskLabel = false);
  }

  void _showBottomBar() {
    if (!_isBottomBarVisible && !_isAnimating) {
      _isAnimating = true;
      _isBottomBarVisible = true;
      _bottomBarAnimationController.reverse().whenComplete(() {
        _isAnimating = false;
      });
    }
    if (!_showAskLabel) setState(() => _showAskLabel = true);
  }

  // Optimized scroll-end detection for auto-showing bottom bar
  void _handleScrollEnd() {
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(milliseconds: 15000), () {
      if (!_isBottomBarVisible && _lastVelocity.abs() < 50) {
        _showBottomBar();
      }
    });
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (!mounted) return;

    // Clear cached data when signing out
    context.read<DataService>().clearCache();

    _userKey = null;
    _checkingAuth = true;
    await RouteErrorManager.instance.pushNamedAndRemoveAllSafely(context, '/login');
  }

  void _computeUpcoming(List<Map<String, dynamic>> events) {
    if (_userKey == null) {
      _upcoming = null;
      return;
    }
    // Filter accepted events for this user
    final List<Map<String, dynamic>> mine = [];
    for (final e in events) {
      if (isAcceptedByUser(e, _userKey)) {
        mine.add(e);
      }
    }
    if (mine.isEmpty) {
      _upcoming = null;
      return;
    }
    // Choose nearest upcoming (today/future and not already started)
    final now = DateTime.now();
    DateTime? bestFuture;
    Map<String, dynamic>? bestFutureEvent;
    for (final e in mine) {
      final dt = _eventDateTime(e);
      if (dt == null) continue;
      if (!dt.isBefore(now)) {
        if (bestFuture == null || dt.isBefore(bestFuture)) {
          bestFuture = dt;
          bestFutureEvent = e;
        }
      }
    }
    _upcoming = bestFutureEvent;
  }

  DateTime? _eventDateTime(Map<String, dynamic> e) {
    final dateStr = e['date']?.toString().trim();
    if (dateStr == null || dateStr.isEmpty) return null;
    final date = _parseDateSafe(dateStr);
    if (date == null) return null;
    final timeStr = e['start_time']?.toString().trim();
    final time = _tryParseTimeOfDay(timeStr);
    if (time != null) {
      return DateTime(date.year, date.month, date.day, time.$1, time.$2);
    }
    // If time is unknown, assume end of day to keep same-day events as upcoming
    return DateTime(date.year, date.month, date.day, 23, 59);
  }

  // Returns (hour, minute) in 24h if parsed, otherwise null
  (int, int)? _tryParseTimeOfDay(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final reg = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$');
    final m = reg.firstMatch(s);
    if (m == null) return null;
    int hour = int.tryParse(m.group(1) ?? '') ?? 0;
    int minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ampm = m.group(3);
    if (ampm != null) {
      final upper = ampm.toUpperCase();
      if (upper == 'AM') {
        if (hour == 12) hour = 0;
      } else if (upper == 'PM') {
        if (hour != 12) hour += 12;
      }
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  // Attempt to parse common date formats used by backend data
  DateTime? _parseDateSafe(String input) {
    // 1) ISO 8601 or YYYY-MM-DD or with time
    try {
      final iso = DateTime.tryParse(input);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    } catch (_) {}
    // 2) MM/DD/YYYY or M/D/YYYY
    final us = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$').firstMatch(input);
    if (us != null) {
      final m = int.tryParse(us.group(1) ?? '');
      final d = int.tryParse(us.group(2) ?? '');
      var y = int.tryParse(us.group(3) ?? '');
      if (m != null && d != null && y != null) {
        if (y < 100) y += 2000; // naive 2-digit year handling
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    // 3) DD/MM/YYYY (EU style). Only use if clearly not US (month > 12)
    final eu = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$').firstMatch(input);
    if (eu != null) {
      final a = int.tryParse(eu.group(1) ?? '');
      final b = int.tryParse(eu.group(2) ?? '');
      var y = int.tryParse(eu.group(3) ?? '');
      if (a != null && b != null && y != null) {
        // treat as DD/MM/YYYY when the first number cannot be a month
        if (a > 12 && b >= 1 && b <= 12) {
          if (y < 100) y += 2000;
          if (a >= 1 && a <= 31) {
            return DateTime(y, b, a);
          }
        }
      }
    }
    // 4) YYYY/MM/DD or YYYY-M-D
    final ymd = RegExp(
      r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$',
    ).firstMatch(input);
    if (ymd != null) {
      final y = int.tryParse(ymd.group(1) ?? '');
      final m = int.tryParse(ymd.group(2) ?? '');
      final d = int.tryParse(ymd.group(3) ?? '');
      if (y != null && m != null && d != null) {
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    return null;
  }

  String _getSmartCountdownText() {
    if (_upcoming == null) return 'No upcoming shifts';

    final eventDt = _eventDateTime(_upcoming!);
    if (eventDt == null) return 'Your next shift is ready';

    final now = DateTime.now();
    final diff = eventDt.difference(now);

    // If event is in the past or happening now
    if (diff.inMinutes <= 0) return 'Shift starting now!';

    // Same day - show hours/minutes countdown
    if (diff.inHours < 24 && eventDt.day == now.day) {
      if (diff.inHours > 0) {
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        if (mins > 0) {
          return 'Starts in $hours hr ${mins} min';
        }
        return 'Starts in $hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return 'Starts in ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'}';
      }
    }

    // Tomorrow
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (eventDt.year == tomorrow.year &&
        eventDt.month == tomorrow.month &&
        eventDt.day == tomorrow.day) {
      final time = _tryParseTimeOfDay(_upcoming!['start_time']?.toString());
      if (time != null) {
        final isPm = time.$1 >= 12;
        int h12 = time.$1 % 12;
        if (h12 == 0) h12 = 12;
        final mm = time.$2.toString().padLeft(2, '0');
        return 'Tomorrow at $h12:$mm ${isPm ? 'PM' : 'AM'}';
      }
      return 'Tomorrow';
    }

    // Future date - show day and time
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[(eventDt.weekday - 1).clamp(0, 6)];
    final month = months[(eventDt.month - 1).clamp(0, 11)];

    final time = _tryParseTimeOfDay(_upcoming!['start_time']?.toString());
    if (time != null) {
      final isPm = time.$1 >= 12;
      int h12 = time.$1 % 12;
      if (h12 == 0) h12 = 12;
      final mm = time.$2.toString().padLeft(2, '0');
      return '$weekday, $month ${eventDt.day} at $h12:$mm ${isPm ? 'PM' : 'AM'}';
    }

    return '$weekday, $month ${eventDt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_checkingAuth) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<DataService>(
      builder: (context, dataService, _) {
        // Compute upcoming event for countdown
        _computeUpcoming(dataService.events);
        final pendingInvites = dataService.pendingInvites.length;
        final terminologyProvider = context.watch<TerminologyProvider>();

        // Auto-detect system language on every build (like Manager app)
        terminologyProvider.updateSystemLanguage(context);

        final showNoTeamBanner = dataService.teamsLoaded && !dataService.hasTeams && _selectedBottomIndex == 0;
        final l10n = AppLocalizations.of(context)!;

        return Scaffold(
          backgroundColor: AppColors.surfaceLight, // Soft off-white (#F8FAFC)
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Optimized scroll detection with velocity tracking
              if (notification is ScrollUpdateNotification) {
                // Ignore horizontal scroll events (like PageView swipes)
                if (notification.metrics.axis != Axis.vertical) return false;

                final metrics = notification.metrics;
                final currentScroll = metrics.pixels;
                final scrollDiff = currentScroll - _lastScrollPosition;

                // Check if we have enough content to warrant hiding navigation
                // Staff app cards have more spacing, so 4 cards = ~320px scrollable content
                if (metrics.maxScrollExtent < 320) {
                  _showBottomBar(); // Always show when content is minimal
                  return false;
                }

                // Track velocity for smoother behavior
                if (notification.dragDetails != null) {
                  _lastVelocity = notification.dragDetails!.primaryDelta ?? 0;
                }

                // Always show at top
                if (currentScroll <= 0) {
                  _showBottomBar();
                  _scrollEndTimer?.cancel();
                }
                // Hide on fast downward scroll or consistent downward movement
                else if ((scrollDiff > _scrollThreshold && currentScroll > 100) ||
                         (_lastVelocity < -_velocityThreshold && currentScroll > 100)) {
                  _hideBottomBar();
                  _handleScrollEnd();
                }
                // Show on upward scroll or fast upward flick
                else if (scrollDiff < -_scrollThreshold || _lastVelocity > _velocityThreshold) {
                  _showBottomBar();
                  _scrollEndTimer?.cancel();
                }

                _lastScrollPosition = currentScroll;
              }
              // Handle scroll end to show bar after user stops scrolling
              else if (notification is ScrollEndNotification) {
                _handleScrollEnd();
              }
              return false;
            },
            child: Column(
              children: [
              Expanded(child: IndexedStack(
              index: _selectedBottomIndex,
              children: [
              _RolesSection(
                events: dataService.events,
                userKey: _userKey,
                loading: dataService.isLoading,
                availability: dataService.availability,
                profileMenu: _buildProfileMenu(context, pendingInvites),
                onHideBottomBar: _hideBottomBar,
                onShowBottomBar: _showBottomBar,
                onTitleTap: _goToMyShifts,
                resetToMyShifts: _resetToMyShifts,
              ), // Shifts tab (index 0) - Default/first tab for better UX
              ConversationsPage(
                profileMenu: _buildProfileMenu(context, pendingInvites, borderColor: AppColors.primaryPurple),
                onTitleTap: _goToMyShifts,
              ), // Chats tab (index 1) - Navy blue border for profile picture
              EarningsPage(
                events: dataService.events,
                userKey: _userKey,
                loading: dataService.isLoading,
                profileMenu: _buildProfileMenu(context, pendingInvites),
                buildAppBar: buildStyledAppBar,
                onTitleTap: _goToMyShifts,
              ),
              _HomeTab(
                events: dataService.events,
                userKey: _userKey,
                loading: dataService.isLoading,
                profileMenu: _buildProfileMenu(context, pendingInvites),
                isRefreshing: dataService.isRefreshing,
                countdownText: _getSmartCountdownText(),
                onHideBottomBar: _hideBottomBar,
                onShowBottomBar: _showBottomBar,
                onTitleTap: _goToMyShifts,
              ),
              ],
              )), // close IndexedStack + Expanded
              ], // close Column children
              ), // close Column
              ), // close NotificationListener
              // AI Assistant floating button — hidden when "no team" banner is active
              if (!showNoTeamBanner)
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 92,
                child: GestureDetector(
                  onTap: () {
                    if (SubscriptionService().isReadOnly) {
                      showSubscriptionRequiredSheet(context, featureName: AppLocalizations.of(context)!.aiAssistant);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StaffAIChatScreen()),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _showAskLabel ? 44 : 38,
                    padding: EdgeInsets.only(
                      left: 4,
                      right: _showAskLabel ? 14 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navySpaceCadet.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(_showAskLabel ? 22 : 19),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navySpaceCadet.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/ai_assistant_logo.png',
                            width: _showAskLabel ? 36 : 30,
                            height: _showAskLabel ? 36 : 30,
                            fit: BoxFit.cover,
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _showAskLabel
                              ? const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text(
                                    'Ask',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Nav bar in Stack so BackdropFilter can sample the scroll content behind it
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                  animation: _bottomBarAnimation,
                  builder: (context, _) {
                    // Measure the bar height after first layout
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final box = _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
                      if (box != null && box.hasSize && _bottomBarHeight != box.size.height) {
                        _bottomBarHeight = box.size.height;
                      }
                    });
                    final progress = _bottomBarAnimation.value.dy;
                    final slideDistance = _bottomBarHeight > 0 ? _bottomBarHeight * 0.72 : 0.0;
                    final translateY = progress * slideDistance;
                    final contentOpacity = (1.0 - progress * 2.5).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, translateY),
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                          child: Container(
                            key: _bottomBarKey,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.75),
                              border: const Border(
                                top: BorderSide(
                                  color: Color(0x1A000000),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: Opacity(
                                  opacity: contentOpacity,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildNavItem(
                                        icon: Icons.work_outline_rounded,
                                        selectedIcon: Icons.work_rounded,
                                        label: terminologyProvider.plural,
                                        index: 0,
                                      ),
                                      _buildNavItem(
                                        icon: Icons.chat_bubble_outline,
                                        selectedIcon: Icons.chat_bubble,
                                        label: 'Chats',
                                        index: 1,
                                      ),
                                      _buildNavItem(
                                        icon: Icons.account_balance_wallet_outlined,
                                        selectedIcon: Icons.account_balance_wallet,
                                        label: l10n.navEarnings,
                                        index: 2,
                                      ),
                                      _buildNavItem(
                                        icon: Icons.access_time_outlined,
                                        selectedIcon: Icons.access_time,
                                        label: 'Clock In',
                                        index: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
              ),
            ),
            // "No team" banner — rendered last so it's above nav bar in z-order
            if (showNoTeamBanner)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 100,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.warning.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.group_off_outlined,
                              size: 22,
                              color: AppColors.warningDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.noTeamBannerTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.warningDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.noTeamBannerMessage,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warningDark.withOpacity(0.8),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const TeamCenterPage()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.warningDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.goToTeams,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    int badgeCount = 0,
  }) {
    final isSelected = _selectedBottomIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {

          setState(() {
            _selectedBottomIndex = index;
            // Reset scroll position and velocity when switching tabs
            _lastScrollPosition = 0;
            _lastVelocity = 0;
            _scrollEndTimer?.cancel();
            // Always show bottom bar when switching tabs with no animation delay
            if (!_isBottomBarVisible) {
              _showBottomBar();
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? selectedIcon : icon,
                    size: 28,
                    color: isSelected ? AppColors.oceanBlue : AppColors.textMuted,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.oceanBlue : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<RoleSummary> _computeRoleSummaries(List<Map<String, dynamic>> events) {
    final Map<String, List<Map<String, dynamic>>> roleToEvents = {};
    final Map<String, int> roleToNeeded = {};
    // Exclude events the current user already accepted
    final Iterable<Map<String, dynamic>> sourceEvents = events.where(
      (e) => !isAcceptedByUser(e, _userKey),
    );
    for (final event in sourceEvents) {
      final roles = event['roles'] as List<dynamic>? ?? const [];
      for (final r in roles) {
        final roleMap = r as Map<String, dynamic>? ?? const {};
        final roleName = (roleMap['role']?.toString() ?? '').trim();
        if (roleName.isEmpty) continue;
        final countStr = roleMap['count']?.toString() ?? '0';
        final count = int.tryParse(countStr) ?? 0;
        roleToEvents.putIfAbsent(roleName, () => <Map<String, dynamic>>[]);
        if (!roleToEvents[roleName]!.contains(event)) {
          roleToEvents[roleName]!.add(event);
        }
        roleToNeeded[roleName] = (roleToNeeded[roleName] ?? 0) + count;
      }
    }
    final summaries = <RoleSummary>[];
    roleToEvents.forEach((role, evs) {
      int? remaining;
      // Prefer backend-provided role_stats if present
      int sumRemaining = 0;
      bool hasAny = false;
      for (final e in evs) {
        final stats = e['role_stats'];
        if (stats is List) {
          for (final s in stats) {
            if (s is Map && (s['role']?.toString() ?? '') == role) {
              final r = int.tryParse(s['remaining']?.toString() ?? '');
              if (r != null) {
                sumRemaining += r;
                hasAny = true;
              }
            }
          }
        }
      }
      if (hasAny) {
        remaining = sumRemaining;
      } else {
        // Fallback: compute remaining from roles[].count minus accepted_staff[].role counts
        int sumCapacity = 0;
        int sumTaken = 0;
        for (final e in evs) {
          final roles = e['roles'];
          if (roles is List) {
            for (final r in roles) {
              if (r is Map && (r['role']?.toString() ?? '') == role) {
                final cap = int.tryParse(r['count']?.toString() ?? '');
                if (cap != null) sumCapacity += cap;
              }
            }
          }
          final accepted = e['accepted_staff'];
          if (accepted is List) {
            for (final a in accepted) {
              if (a is Map && (a['role']?.toString() ?? '') == role) {
                sumTaken += 1;
              }
            }
          }
        }
        remaining = (sumCapacity - sumTaken);
        if (remaining < 0) remaining = 0;
      }

      summaries.add(
        RoleSummary(
          roleName: role,
          totalNeeded: roleToNeeded[role] ?? 0,
          eventCount: evs.length,
          events: evs,
          remainingTotal: remaining,
        ),
      );
    });
    summaries.sort((a, b) {
      final needed = b.totalNeeded.compareTo(a.totalNeeded);
      if (needed != 0) return needed;
      final ev = b.eventCount.compareTo(a.eventCount);
      if (ev != 0) return ev;
      return a.roleName.toLowerCase().compareTo(b.roleName.toLowerCase());
    });
    return summaries;
  }

  Widget _buildProfileMenu(BuildContext context, int pendingInvites, {Color? borderColor}) {
    return PopupMenuButton<_AccountMenuAction>(
      tooltip: 'Account',
      onSelected: (value) async {
        switch (value) {
          case _AccountMenuAction.profile:
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const UserProfilePage()),
            );
            await _loadUserProfile();
            break;
          case _AccountMenuAction.teams:
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const TeamCenterPage()),
            );
            break;
          case _AccountMenuAction.logout:
            _signOut();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountMenuAction>(
          value: _AccountMenuAction.profile,
          child: Row(
            children: [
              Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.myProfile),
            ],
          ),
        ),
        PopupMenuItem<_AccountMenuAction>(
          value: _AccountMenuAction.teams,
          child: Row(
            children: [
              Icon(
                Icons.groups_outlined,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.teams),
              if (pendingInvites > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pendingInvites',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        PopupMenuItem<_AccountMenuAction>(
          value: _AccountMenuAction.logout,
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.logout),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _userPictureUrl != null
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor ?? AppColors.primaryIndigo, width: 2),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  backgroundImage: NetworkImage(_userPictureUrl!),
                ),
              )
            : const Icon(Icons.account_circle, size: 28, color: Colors.white),
      ),
    );
  }

}

// Custom clipper for beautiful curved appbar shape with smooth elliptical bottom-right corner
class AppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    // Start from top-left corner
    path.moveTo(0, 0);

    // Top edge - straight across
    path.lineTo(width, 0);

    // Right edge - go down but stop before the corner for the curve
    path.lineTo(width, height - 60);

    // Beautiful elliptical rounded bottom-right corner
    // Using cubicTo for ultra-smooth curve
    path.cubicTo(
      width,
      height - 30, // First control point - ease out from vertical
      width - 30,
      height, // Second control point - ease into horizontal
      width - 60,
      height, // End point - curved inward
    );

    // Bottom edge - straight across to left
    path.lineTo(0, height);

    // Close the path back to top-left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Shared AppBar builder for consistent styling across Clock In, Roles, and Earnings tabs
// Fixed pinned header - always visible, doesn't collapse
// Note: Subtitle is deprecated for Shifts section (kept for backward compatibility with other sections)
Widget buildStyledAppBar({
  required BuildContext context,
  required String title,
  required Widget profileMenu,
  String? subtitle, // Optional subtitle (deprecated for Shifts, still used by Clock In/Earnings)
  Widget? bottomWidget,
  VoidCallback? onTitleTap,
}) {
  // Get the safe area top padding for proper positioning on notched devices
  final topPadding = MediaQuery.of(context).padding.top;

  // If subtitle is provided, create a Text widget for bottomWidget
  // This maintains backward compatibility with sections still using subtitle
  Widget? effectiveBottomWidget = bottomWidget;
  if (subtitle != null && bottomWidget == null) {
    effectiveBottomWidget = Text(
      subtitle,
      style: TextStyle(
        color: Colors.white.withOpacity(0.85),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  return SliverPersistentHeader(
    pinned: true,
    delegate: _FixedAppBarDelegate(
      title: title,
      profileMenu: profileMenu,
      bottomWidget: effectiveBottomWidget,
      topPadding: topPadding,
      onTitleTap: onTitleTap,
    ),
  );
}

// Delegate for fixed app bar header
class _FixedAppBarDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final Widget profileMenu;
  final Widget? bottomWidget; // Optional widget at bottom (e.g., filter toggle)
  final double topPadding; // Safe area top padding
  final VoidCallback? onTitleTap;

  _FixedAppBarDelegate({
    required this.title,
    required this.profileMenu,
    this.bottomWidget,
    required this.topPadding,
    this.onTitleTap,
  });

  @override
  double get minExtent => topPadding + 56.0; // Safe area + content height

  @override
  double get maxExtent => topPadding + 56.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.navySpaceCadet.withValues(alpha: 0.92),
                  AppColors.oceanBlue.withValues(alpha: 0.88),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 8, // Safe area + extra padding
                left: 20,
                right: 20,
                bottom: 12,
              ),
              child: Row(
                children: [
                  // Title
                  GestureDetector(
                    onTap: onTitleTap,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Eye icon toggle (for Available view)
                  if (bottomWidget != null) bottomWidget!,
                  const Spacer(),
                  // Profile menu
                  profileMenu,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_FixedAppBarDelegate oldDelegate) {
    return title != oldDelegate.title ||
        profileMenu != oldDelegate.profileMenu ||
        bottomWidget != oldDelegate.bottomWidget ||
        topPadding != oldDelegate.topPadding;
  }
}

class _HomeTab extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  final Widget profileMenu;
  final bool isRefreshing;
  final String countdownText;
  final VoidCallback? onHideBottomBar;
  final VoidCallback? onShowBottomBar;
  final VoidCallback? onTitleTap;
  const _HomeTab({
    required this.events,
    required this.userKey,
    required this.loading,
    required this.profileMenu,
    required this.isRefreshing,
    required this.countdownText,
    this.onHideBottomBar,
    this.onShowBottomBar,
    this.onTitleTap,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic>? _upcoming;
  bool _loading = false;
  String? _status; // not_started | clocked_in | completed
  String? _acceptedRole; // The role name the user accepted for this event
  bool _canClockIn = false;
  String? _clockInError;
  Timer? _validationTimer;
  Timer? _elapsedTimer;
  DateTime? _clockInTime;
  String _elapsedTimeText = '00:00:00';

  @override
  void initState() {
    super.initState();
    _computeUpcoming();
    // Start periodic validation check every 30 seconds
    _validationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_upcoming != null && _status == null) {
        _validateClockIn();
      }
    });
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _startElapsedTimer() {
    // Only set _clockInTime if not already set (e.g., restored from server)
    _clockInTime ??= DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_clockInTime != null && mounted) {
        final elapsed = DateTime.now().difference(_clockInTime!);
        final hours = elapsed.inHours.toString().padLeft(2, '0');
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          _elapsedTimeText = '$hours:$minutes:$seconds';
        });
      }
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _clockInTime = null;
    setState(() {
      _elapsedTimeText = '00:00:00';
    });
  }

  @override
  void didUpdateWidget(covariant _HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events ||
        oldWidget.userKey != widget.userKey) {
      _computeUpcoming();
    }
  }

  void _computeUpcoming() async {
    print('[CLOCK-IN] _computeUpcoming called - userKey: ${widget.userKey}, total events: ${widget.events.length}');

    // Preserve clock-in state if already clocked in (don't reset mid-shift)
    final preserveClockIn = _status == 'clocked_in' && _clockInTime != null;
    final previousStatus = _status;
    final previousClockInTime = _clockInTime;

    setState(() {
      _upcoming = null;
      // Don't reset status if we're actively clocked in
      if (!preserveClockIn) {
        _status = null;
      }
      _acceptedRole = null;
    });
    if (widget.userKey == null) {
      print('[CLOCK-IN] userKey is null, returning');
      return;
    }
    // Filter accepted events for this user and extract the role
    final List<Map<String, dynamic>> mine = [];
    final Map<Map<String, dynamic>, String?> eventRoles = {};
    for (final e in widget.events) {
      final acceptedEntry = findAcceptedStaffEntry(e, widget.userKey);
      if (acceptedEntry != null) {
        mine.add(e);
        eventRoles[e] = acceptedEntry['role']?.toString();
      }
    }
    print('[CLOCK-IN] Found ${mine.length} events for this user');
    if (mine.isEmpty) {
      print('[CLOCK-IN] No events found for user, returning');
      return;
    }
    // Choose nearest upcoming event (today or future, prioritize by date/time)
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    DateTime? bestFuture;
    Map<String, dynamic>? bestFutureEvent;
    for (final e in mine) {
      final dt = _eventDateTime(e);
      if (dt == null) continue;
      // Include if event date is today or future (ignore time for today)
      final eventDate = DateTime(dt.year, dt.month, dt.day);
      if (!eventDate.isBefore(todayStart)) {
        if (bestFuture == null || dt.isBefore(bestFuture)) {
          bestFuture = dt;
          bestFutureEvent = e;
        }
      }
    }
    if (bestFutureEvent == null) {
      setState(() {
        _upcoming = null;
        _status = null;
        _acceptedRole = null;
      });
      return;
    }
    final next = bestFutureEvent;
    _upcoming = next;
    _acceptedRole = eventRoles[next];
    // Load attendance state
    final id = resolveEventId(next);
    if (id == null) return;
    setState(() {
      _loading = true;
    });
    final resp = await AuthService.getMyAttendanceStatus(eventId: id);
    final isClockedIn = resp?['isClockedIn'] == true;
    final lastClockInAt = resp?['lastClockInAt']?.toString();

    setState(() {
      _loading = false;

      // If we were clocked in and have an active timer, preserve local state
      if (preserveClockIn) {
        _status = previousStatus;
        _clockInTime = previousClockInTime;
        print('[CLOCK-IN] Preserved clock-in state: $_status');
      }
      // If server says we're clocked in, restore the timer from server time
      else if (isClockedIn && lastClockInAt != null) {
        _status = 'clocked_in';
        try {
          _clockInTime = DateTime.parse(lastClockInAt).toLocal();
          print('[CLOCK-IN] Restored clock-in from server: $_clockInTime');
        } catch (e) {
          _clockInTime = DateTime.now();
          print('[CLOCK-IN] Failed to parse clockInAt, using now: $e');
        }
      } else {
        _status = resp?['status']?.toString();
      }
    });

    // Start elapsed timer if we're clocked in (restored from server)
    if (_status == 'clocked_in' && _clockInTime != null && !preserveClockIn) {
      _startElapsedTimer();
      print('[CLOCK-IN] ✓ Timer restored from server with clockInTime: $_clockInTime');
    }

    // Validate clock-in conditions after loading
    if (_status == null) {
      _validateClockIn();
    }
  }

  DateTime? _eventDateTime(Map<String, dynamic> e) {
    final dateStr = e['date']?.toString().trim();
    if (dateStr == null || dateStr.isEmpty) return null;
    final date = _parseDateSafe(dateStr);
    if (date == null) return null;
    final timeStr = e['start_time']?.toString().trim();
    final time = _tryParseTimeOfDay(timeStr);
    if (time != null) {
      return DateTime(date.year, date.month, date.day, time.$1, time.$2);
    }
    // If time is unknown, assume end of day to keep same-day events as upcoming
    return DateTime(date.year, date.month, date.day, 23, 59);
  }

  // Returns (hour, minute) in 24h if parsed, otherwise null
  (int, int)? _tryParseTimeOfDay(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final reg = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$');
    final m = reg.firstMatch(s);
    if (m == null) return null;
    int hour = int.tryParse(m.group(1) ?? '') ?? 0;
    int minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ampm = m.group(3);
    if (ampm != null) {
      final upper = ampm.toUpperCase();
      if (upper == 'AM') {
        if (hour == 12) hour = 0;
      } else if (upper == 'PM') {
        if (hour != 12) hour += 12;
      }
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  // Attempt to parse common date formats used by backend data
  DateTime? _parseDateSafe(String input) {
    // 1) ISO 8601 or YYYY-MM-DD or with time
    try {
      final iso = DateTime.tryParse(input);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    } catch (_) {}
    // 2) MM/DD/YYYY or M/D/YYYY
    final us = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$').firstMatch(input);
    if (us != null) {
      final m = int.tryParse(us.group(1) ?? '');
      final d = int.tryParse(us.group(2) ?? '');
      var y = int.tryParse(us.group(3) ?? '');
      if (m != null && d != null && y != null) {
        if (y < 100) y += 2000; // naive 2-digit year handling
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    // 3) DD/MM/YYYY (EU style). Only use if clearly not US (month > 12)
    final eu = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$').firstMatch(input);
    if (eu != null) {
      final a = int.tryParse(eu.group(1) ?? '');
      final b = int.tryParse(eu.group(2) ?? '');
      var y = int.tryParse(eu.group(3) ?? '');
      if (a != null && b != null && y != null) {
        // treat as DD/MM/YYYY when the first number cannot be a month
        if (a > 12 && b >= 1 && b <= 12) {
          if (y < 100) y += 2000;
          if (a >= 1 && a <= 31) {
            return DateTime(y, b, a);
          }
        }
      }
    }
    // 4) YYYY/MM/DD or YYYY-M-D
    final ymd = RegExp(
      r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$',
    ).firstMatch(input);
    if (ymd != null) {
      final y = int.tryParse(ymd.group(1) ?? '');
      final m = int.tryParse(ymd.group(2) ?? '');
      final d = int.tryParse(ymd.group(3) ?? '');
      if (y != null && m != null && d != null) {
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    return null;
  }

  int? _parseTimeMinutes(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$').firstMatch(s);
    if (m == null) return null;
    int hour = int.tryParse(m.group(1) ?? '0') ?? 0;
    final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ampm = m.group(3);
    if (ampm != null) {
      final u = ampm.toUpperCase();
      if (u == 'AM') {
        if (hour == 12) hour = 0;
      } else if (u == 'PM') {
        if (hour != 12) hour += 12;
      }
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  String _getSmartCountdownText() {
    if (_upcoming == null) return 'No upcoming shifts';

    final eventDt = _eventDateTime(_upcoming!);
    if (eventDt == null) return 'Your next shift is ready';

    final now = DateTime.now();
    final diff = eventDt.difference(now);

    // If event is in the past or happening now
    if (diff.inMinutes <= 0) return 'Shift starting now!';

    // Same day - show hours/minutes countdown
    if (diff.inHours < 24 && eventDt.day == now.day) {
      if (diff.inHours > 0) {
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        if (mins > 0) {
          return 'Starts in $hours hr ${mins} min';
        }
        return 'Starts in $hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return 'Starts in ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'}';
      }
    }

    // Tomorrow
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (eventDt.year == tomorrow.year &&
        eventDt.month == tomorrow.month &&
        eventDt.day == tomorrow.day) {
      final time = _tryParseTimeOfDay(_upcoming!['start_time']?.toString());
      if (time != null) {
        final isPm = time.$1 >= 12;
        int h12 = time.$1 % 12;
        if (h12 == 0) h12 = 12;
        final mm = time.$2.toString().padLeft(2, '0');
        return 'Tomorrow at $h12:$mm ${isPm ? 'PM' : 'AM'}';
      }
      return 'Tomorrow';
    }

    // Future date - show day and time
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[(eventDt.weekday - 1).clamp(0, 6)];
    final month = months[(eventDt.month - 1).clamp(0, 11)];

    final time = _tryParseTimeOfDay(_upcoming!['start_time']?.toString());
    if (time != null) {
      final isPm = time.$1 >= 12;
      int h12 = time.$1 % 12;
      if (h12 == 0) h12 = 12;
      final mm = time.$2.toString().padLeft(2, '0');
      return '$weekday, $month ${eventDt.day} at $h12:$mm ${isPm ? 'PM' : 'AM'}';
    }

    return '$weekday, $month ${eventDt.day}';
  }

  Future<void> _clockIn() async {
    if (_upcoming == null) return;
    final id = resolveEventId(_upcoming!);
    if (id == null) return;

    print('[CLOCK-IN] Button pressed, starting clock-in...');
    setState(() {
      _loading = true;
    });

    // Check network status
    final isOnline = await SyncService.isOnline();
    print('[CLOCK-IN] Network status: ${isOnline ? "online" : "offline"}');

    // Get current location for caching
    Position? currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition();
      // Cache location for offline clock-out
      await OfflineService.cacheLocation(id, currentPosition);
      print('[CLOCK-IN] Location cached for event: $id');
    } catch (e) {
      print('[CLOCK-IN] Failed to cache location: $e');
    }

    if (isOnline) {
      // Online: Try API call
      try {
        print('[CLOCK-IN] Calling API with eventId: $id');
        final res = await AuthService.clockIn(
          eventId: id,
          latitude: currentPosition?.latitude,
          longitude: currentPosition?.longitude,
          locationSource: 'live',
        );
        print('[CLOCK-IN] API response: $res');

        // Check if already clocked in
        final message = res?['message']?.toString() ?? '';
        final alreadyClockedIn = message.toLowerCase().contains('already clocked in');

        // Extract clockInAt timestamp from response
        final clockInAtStr = res?['clockInAt']?.toString();
        DateTime? clockInTime;
        if (clockInAtStr != null) {
          try {
            clockInTime = DateTime.parse(clockInAtStr);
            print('[CLOCK-IN] Parsed clockInAt: $clockInTime');
          } catch (e) {
            print('[CLOCK-IN] Failed to parse clockInAt: $e');
          }
        }

        setState(() {
          _loading = false;
          _status = res?['status']?.toString() ?? (alreadyClockedIn ? 'clocked_in' : _status);
          // Set clock-in time from server response
          if (clockInTime != null) {
            _clockInTime = clockInTime;
          }
        });

        // Start elapsed timer if successfully clocked in (new or existing)
        if (_status == 'clocked_in' && clockInTime != null) {
          _startElapsedTimer();
          print('[CLOCK-IN] ✓ Timer started with clockInTime: $_clockInTime');
        }

        // Show appropriate message
        if (mounted && context.mounted) {
          if (alreadyClockedIn) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.timerRestored),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.clockedInSuccessfully),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        print('[CLOCK-IN] ✓ Clock-in successful, status: $_status');
      } catch (e) {
        // API call failed - queue offline action
        print('[CLOCK-IN] API failed, queuing offline action: $e');
        await _queueOfflineClockIn(id, currentPosition);
      }
    } else {
      // Offline: Queue action immediately
      print('[CLOCK-IN] Offline mode - queuing action');
      await _queueOfflineClockIn(id, currentPosition);
    }
  }

  Future<void> _queueOfflineClockIn(String eventId, Position? position) async {
    try {
      final action = PendingClockAction(
        id: '${eventId}_clockin_${DateTime.now().millisecondsSinceEpoch}',
        action: 'clock-in',
        eventId: eventId,
        timestamp: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
        locationSource: 'live',
      );

      await OfflineService.addPendingAction(action);

      // Update UI optimistically
      setState(() {
        _loading = false;
        _status = 'clocked_in';
        _clockInTime = DateTime.now();
      });

      _startElapsedTimer();

      // Show offline message
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(AppLocalizations.of(context)!.clockedInOffline),
                ),
              ],
            ),
            backgroundColor: AppColors.purpleLight,
            duration: Duration(seconds: 3),
          ),
        );
      }

      print('[CLOCK-IN] ✓ Queued offline clock-in');

      // Try immediate sync in background
      SyncService.syncPendingActions().then((count) {
        if (count > 0) {
          print('[CLOCK-IN] Synced $count offline actions');
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to queue clock-in: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _clockOut() async {
    if (_upcoming == null) return;
    final id = resolveEventId(_upcoming!);
    if (id == null) return;

    print('[CLOCK-OUT] Button pressed, starting clock-out...');
    setState(() {
      _loading = true;
    });

    // Check network status
    final isOnline = await SyncService.isOnline();
    print('[CLOCK-OUT] Network status: ${isOnline ? "online" : "offline"}');

    // Get location (current or cached)
    double? latitude;
    double? longitude;
    String locationSource = 'live';

    try {
      final currentPosition = await Geolocator.getCurrentPosition();
      latitude = currentPosition.latitude;
      longitude = currentPosition.longitude;
      print('[CLOCK-OUT] Using live location');
    } catch (e) {
      // Failed to get current location, try cached
      print('[CLOCK-OUT] Failed to get live location: $e');
      final cached = await OfflineService.getCachedLocation(id);
      if (cached != null) {
        latitude = cached['latitude'] as double?;
        longitude = cached['longitude'] as double?;
        locationSource = 'cached';
        print('[CLOCK-OUT] Using cached location from clock-in');
      }
    }

    if (isOnline) {
      // Online: Try API call
      try {
        print('[CLOCK-OUT] Calling API with eventId: $id');
        final res = await AuthService.clockOut(eventId: id);
        print('[CLOCK-OUT] API response: $res');

        setState(() {
          _loading = false;
          _status = res?['status']?.toString() ?? _status;
        });

        // Stop elapsed timer
        _stopElapsedTimer();

        // Remove cached location
        await OfflineService.removeCachedLocation(id);

        // Show success message
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.clockedOutSuccessfully(_elapsedTimeText)),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        print('[CLOCK-OUT] ✓ Clock-out successful, status: $_status');
      } catch (e) {
        // API call failed - queue offline action
        print('[CLOCK-OUT] API failed, queuing offline action: $e');
        await _queueOfflineClockOut(id, latitude, longitude, locationSource);
      }
    } else {
      // Offline: Queue action immediately
      print('[CLOCK-OUT] Offline mode - queuing action');
      await _queueOfflineClockOut(id, latitude, longitude, locationSource);
    }
  }

  Future<void> _queueOfflineClockOut(
    String eventId,
    double? latitude,
    double? longitude,
    String locationSource,
  ) async {
    try {
      final action = PendingClockAction(
        id: '${eventId}_clockout_${DateTime.now().millisecondsSinceEpoch}',
        action: 'clock-out',
        eventId: eventId,
        timestamp: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        locationSource: locationSource,
      );

      await OfflineService.addPendingAction(action);

      // Update UI optimistically
      setState(() {
        _loading = false;
        _status = 'clocked_out';
      });

      _stopElapsedTimer();

      // Show offline message
      if (mounted && context.mounted) {
        final locationWarning = locationSource == 'cached'
          ? ' (using clock-in location)'
          : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✓ Clocked out (offline)$locationWarning - Will sync when online',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.purpleLight,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      print('[CLOCK-OUT] ✓ Queued offline clock-out (location: $locationSource)');

      // Try immediate sync in background
      SyncService.syncPendingActions().then((count) {
        if (count > 0) {
          print('[CLOCK-OUT] Synced $count offline actions');
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to queue clock-out: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _validateClockIn() async {
    if (_upcoming == null) {
      setState(() {
        _canClockIn = false;
        _clockInError = null;
      });
      return;
    }

    try {
      print('[CLOCK-IN] Starting validation...');
      // Check 1: Date and time validation
      final eventDt = _eventDateTime(_upcoming!);
      if (eventDt == null) {
        print('[CLOCK-IN] ✗ No event date/time');
        setState(() {
          _canClockIn = false;
          _clockInError = AppLocalizations.of(context)!.eventDateTimeNotAvailable;
        });
        return;
      }

      final now = DateTime.now();
      print('[CLOCK-IN] Event time: $eventDt');
      print('[CLOCK-IN] Current time: $now');

      // Allow clock-in 30 minutes before the event starts
      final earliestClockIn = eventDt.subtract(const Duration(minutes: 30));
      print('[CLOCK-IN] Earliest clock-in: $earliestClockIn');
      // Allow clock-in until the end time
      final endTimeStr = _upcoming!['end_time']?.toString().trim();
      final endTime = _tryParseTimeOfDay(endTimeStr);
      DateTime latestClockIn;
      if (endTime != null) {
        latestClockIn = DateTime(
          eventDt.year,
          eventDt.month,
          eventDt.day,
          endTime.$1,
          endTime.$2,
        );
      } else {
        // If no end time, allow clock-in for 12 hours after start
        latestClockIn = eventDt.add(const Duration(hours: 12));
      }

      if (now.isBefore(earliestClockIn)) {
        final duration = earliestClockIn.difference(now);
        String timeMessage;

        if (duration.inDays > 0) {
          final days = duration.inDays;
          final hours = duration.inHours % 24;
          if (hours > 0) {
            timeMessage =
                '$days day${days > 1 ? 's' : ''} and $hours hour${hours > 1 ? 's' : ''}';
          } else {
            timeMessage = '$days day${days > 1 ? 's' : ''}';
          }
        } else if (duration.inHours > 0) {
          final hours = duration.inHours;
          final minutes = duration.inMinutes % 60;
          if (minutes > 0) {
            timeMessage =
                '$hours hour${hours > 1 ? 's' : ''} and $minutes min${minutes > 1 ? 's' : ''}';
          } else {
            timeMessage = '$hours hour${hours > 1 ? 's' : ''}';
          }
        } else {
          final minutes = duration.inMinutes;
          timeMessage = '$minutes minute${minutes > 1 ? 's' : ''}';
        }

        print('[CLOCK-IN] ✗ Too early: $timeMessage until clock-in available');
        setState(() {
          _canClockIn = false;
          _clockInError = 'Clock in available in $timeMessage';
        });
        return;
      }

      // Allow late clock-in if event is today (same date)
      final eventDate = DateTime(eventDt.year, eventDt.month, eventDt.day);
      final todayDate = DateTime(now.year, now.month, now.day);
      final isToday = eventDate.isAtSameMomentAs(todayDate);

      if (!isToday && now.isAfter(latestClockIn)) {
        print('[CLOCK-IN] ✗ Event time has passed (not today)');
        setState(() {
          _canClockIn = false;
          _clockInError = AppLocalizations.of(context)!.eventTimePassed;
        });
        return;
      }

      if (isToday) {
        print('[CLOCK-IN] ✓ Event is today - allowing late clock-in');
      } else {
        print('[CLOCK-IN] ✓ Time check passed');
      }

      // Check 2: Location validation
      final venueAddress = _upcoming!['venue_address']?.toString() ?? '';
      print('[CLOCK-IN] Venue address: $venueAddress');
      if (venueAddress.isEmpty) {
        // If no venue address, skip location check
        print('[CLOCK-IN] ✓ No venue address required - ENABLED');
        setState(() {
          _canClockIn = true;
          _clockInError = null;
        });
        return;
      }

      // Check location permission
      print('[CLOCK-IN] Checking location permission...');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('[CLOCK-IN] Permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[CLOCK-IN] ✗ Location permission denied');
          setState(() {
            _canClockIn = false;
            _clockInError = 'Location permission required';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[CLOCK-IN] ✗ Location permission denied forever');
        setState(() {
          _canClockIn = false;
          _clockInError = 'Location permission denied. Enable in settings.';
        });
        return;
      }

      print('[CLOCK-IN] ✓ Permission granted: $permission');

      // Get current location
      Position position;
      try {
        print('[CLOCK-IN] Getting current location...');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        print('[CLOCK-IN] Current position: (${position.latitude}, ${position.longitude})');
      } catch (e) {
        print('[CLOCK-IN] ✗ Failed to get location: $e');
        setState(() {
          _canClockIn = false;
          _clockInError = 'Unable to get current location';
        });
        return;
      }

      // Get venue coordinates from address
      List<Location> locations;
      try {
        print('[CLOCK-IN] Geocoding venue address...');
        locations = await locationFromAddress(venueAddress);
      } catch (e) {
        // If geocoding fails, allow clock-in (venue address might be invalid)
        print('[CLOCK-IN] ⚠ Geocoding failed, allowing clock-in: $e');
        setState(() {
          _canClockIn = true;
          _clockInError = null;
        });
        return;
      }

      if (locations.isEmpty) {
        print('[CLOCK-IN] ⚠ No coordinates found, allowing clock-in');
        setState(() {
          _canClockIn = true;
          _clockInError = null;
        });
        return;
      }

      final venueLocation = locations.first;
      print('[CLOCK-IN] Venue position: (${venueLocation.latitude}, ${venueLocation.longitude})');

      final distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        venueLocation.latitude,
        venueLocation.longitude,
      );

      print('[CLOCK-IN] Distance: ${distanceInMeters.toStringAsFixed(0)}m');

      // Allow clock-in within 500 meters (adjust as needed)
      const maxDistanceMeters = 500.0;
      if (distanceInMeters > maxDistanceMeters) {
        final distanceKm = (distanceInMeters / 1000).toStringAsFixed(1);
        print('[CLOCK-IN] ✗ Too far from venue: ${distanceKm}km away');
        setState(() {
          _canClockIn = false;
          _clockInError = 'Too far from venue (${distanceKm}km away)';
        });
        return;
      }

      // All checks passed!
      print('[CLOCK-IN] ✓✓ ALL CHECKS PASSED - ENABLED');
      setState(() {
        _canClockIn = true;
        _clockInError = null;
      });
    } catch (e) {
      debugPrint('Clock-in validation error: $e');
      setState(() {
        _canClockIn = false;
        _clockInError = 'Validation error';
      });
    }
  }

  Future<void> _launchMap(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch map';
      }
    } catch (e) {
      print('Error launching map: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Debug logging
    print('[CLOCK-IN] Building with: userKey=${widget.userKey}, loading=${widget.loading}, events=${widget.events.length}, upcoming=$_upcoming, status=$_status');

    return EnhancedRefreshIndicator(
      showLastRefreshTime: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          buildStyledAppBar(
            context: context,
            title: 'Clock In',
            subtitle: widget.countdownText,
            profileMenu: widget.profileMenu,
            onTitleTap: widget.onTitleTap,
          ),
          const SliverToBoxAdapter(child: FreeMonthBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_upcoming == null && !widget.loading) ...[
                    const SizedBox(height: 24),
                    Image.asset(
                      'assets/clock_in_empty.png',
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No upcoming events',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.navySpaceCadet,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accept an event from the Shifts tab to see it here',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.navySpaceCadet.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_upcoming != null) ...[
                    _buildEventCard(theme),
                    const SizedBox(height: 24),
                    _buildClockActions(theme),
                    if (_status == 'completed') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.success, AppColors.success],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Shift completed successfully!',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(ThemeData theme) {
    final e = _upcoming!;
    final title = e['event_name']?.toString() ?? 'Upcoming Event';
    final venue =
        e['event_name']?.toString() ?? e['venue_name']?.toString() ?? '';
    final venueAddress = e['venue_address']?.toString() ?? '';
    final rawMaps = e['google_maps_url']?.toString() ?? '';
    final googleMapsUrl = rawMaps.isNotEmpty
        ? rawMaps
        : (venueAddress.isNotEmpty ? venueAddress : venue);
    final date = e['date']?.toString() ?? '';
    final start = e['start_time']?.toString() ?? '';
    final end = e['end_time']?.toString() ?? '';
    final clientName = e['client_name']?.toString() ?? '';

    // Check if event is private
    final visibilityType = e['visibilityType']?.toString() ?? '';
    final isPrivate = visibilityType == 'private';

    // Calculate shift duration
    String? durationLabel;
    final startMins = _parseTimeMinutes(start);
    final endMins = _parseTimeMinutes(end);
    if (startMins != null && endMins != null && endMins > startMins) {
      final mins = endMins - startMins;
      final hours = (mins / 60).floor();
      final rem = mins % 60;
      durationLabel = rem == 0 ? '$hours hrs' : '$hours hrs ${rem}m';
    }

    // Calculate estimated earnings
    String? estimatedPay;
    if (_acceptedRole != null && _acceptedRole!.isNotEmpty) {
      final roles = e['roles'];
      if (roles is List) {
        for (final r in roles) {
          if (r is Map && (r['role']?.toString() ?? '') == _acceptedRole) {
            final tariff = r['tariff'];
            if (tariff is Map) {
              final rate = tariff['rate']?.toString();
              final currency = tariff['currency']?.toString() ?? '\$';
              final rateValue = double.tryParse(rate ?? '');
              if (rateValue != null &&
                  startMins != null &&
                  endMins != null &&
                  endMins > startMins) {
                final hours = (endMins - startMins) / 60.0;
                final total = hours * rateValue;
                estimatedPay = '$currency${total.toStringAsFixed(2)}';
              }
            }
            break;
          }
        }
      }
    }

    // Real data is now available from backend!

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: AppColors.navySpaceCadet.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role as main title
            if (_acceptedRole?.isNotEmpty ?? false) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.navySpaceCadet,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.work_rounded,
                      size: 20,
                      color: AppColors.yellow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _acceptedRole!,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.navySpaceCadet,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Event name as subtitle
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.navySpaceCadet.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              // Fallback if no role
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.navySpaceCadet,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navySpaceCadet,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Client badge
            if (clientName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navySpaceCadet.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 14,
                        color: AppColors.navySpaceCadet.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        clientName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.navySpaceCadet,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Date & Time - Prominent section
            if (date.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.navySpaceCadet.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.navySpaceCadet,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: AppColors.yellow,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatEventDateTimeLabel(
                          dateStr: date,
                          startTimeStr: start,
                          endTimeStr: end,
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navySpaceCadet,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Address
            if (venue.isNotEmpty ||
                venueAddress.isNotEmpty ||
                googleMapsUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.navySpaceCadet.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.navySpaceCadet.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.navySpaceCadet.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (venueAddress.isNotEmpty)
                            Text(
                              venueAddress,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.navySpaceCadet,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (venue.isNotEmpty)
                            Text(
                              venue,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.navySpaceCadet,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (googleMapsUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.navySpaceCadet,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _launchMap(googleMapsUrl),
                            child: const Icon(
                              Icons.directions_rounded,
                              size: 18,
                              color: AppColors.yellow,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            // Duration and Earnings - Highlighted section
            if (durationLabel != null || estimatedPay != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (durationLabel != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navySpaceCadet.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 20,
                              color: AppColors.navySpaceCadet.withOpacity(0.7),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              durationLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navySpaceCadet,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Duration',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.navySpaceCadet.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (durationLabel != null && estimatedPay != null)
                    const SizedBox(width: 12),
                  if (estimatedPay != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navySpaceCadet,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payments_rounded,
                              size: 20,
                              color: AppColors.yellow.withOpacity(0.8),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              estimatedPay,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.yellow,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context)!.estimated,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              // Tax reminder
              if (estimatedPay != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navySpaceCadet.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.navySpaceCadet.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Estimate does not include applicable taxes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.navySpaceCadet.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClockActions(ThemeData theme) {
    return Column(
      children: [
        if (_status == null || _status == 'not_started') ...[
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: _canClockIn
                  ? AppColors.navySpaceCadet
                  : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _canClockIn
                  ? [
                      BoxShadow(
                        color: AppColors.navySpaceCadet.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton.icon(
              onPressed: (!_loading && _canClockIn) ? _clockIn : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.yellow,
                      ),
                    )
                  : const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.yellow,
                      size: 24,
                    ),
              label: Text(
                _loading ? 'Clocking in...' : 'Clock In',
                style: const TextStyle(
                  color: AppColors.yellow,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_clockInError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navySpaceCadet.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.navySpaceCadet.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _clockInError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.navySpaceCadet,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (_status == 'clocked_in') ...[
          // Elapsed time display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.navySpaceCadet.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.navySpaceCadet,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.timer,
                        color: AppColors.yellow,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Time Worked',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navySpaceCadet.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _elapsedTimeText,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navySpaceCadet,
                    letterSpacing: 2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Started at ${_clockInTime != null ? "${_clockInTime!.hour.toString().padLeft(2, '0')}:${_clockInTime!.minute.toString().padLeft(2, '0')}" : "--:--"}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navySpaceCadet.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Clock out button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.error, Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: !_loading ? _clockOut : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.stop_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
              label: Text(
                _loading ? 'Clocking out...' : 'Clock Out',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Enum for view mode selection in roles section
enum _ViewMode { available, myEvents, calendar }

// Filter chips delegate for pinned header
class _FilterChipsDelegate extends SliverPersistentHeaderDelegate {
  final _ViewMode selectedView;
  final Function(_ViewMode) onViewChanged;
  final String myTerminology;

  _FilterChipsDelegate({
    required this.selectedView,
    required this.onViewChanged,
    required this.myTerminology,
  });

  @override
  double get minExtent => 80.0;

  @override
  double get maxExtent => 80.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            color: theme.colorScheme.surfaceContainerLowest.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: Row(
                children: [
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.available),
                    avatar: const Icon(Icons.work_outline, size: 18),
                    selected: selectedView == _ViewMode.available,
                    onSelected: (selected) {
                      if (selected) onViewChanged(_ViewMode.available);
                    },
                    selectedColor: AppColors.primaryIndigo,
                    labelStyle: TextStyle(
                      color: selectedView == _ViewMode.available
                          ? Colors.white
                          : const Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: const Color(0xFF2C3E50),
                      width: selectedView == _ViewMode.available ? 0 : 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(myTerminology),
                    avatar: const Icon(Icons.event_available, size: 18),
                    selected: selectedView == _ViewMode.myEvents,
                    onSelected: (selected) {
                      if (selected) onViewChanged(_ViewMode.myEvents);
                    },
                    selectedColor: AppColors.primaryIndigo,
                    labelStyle: TextStyle(
                      color: selectedView == _ViewMode.myEvents
                          ? Colors.white
                          : const Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: const Color(0xFF2C3E50),
                      width: selectedView == _ViewMode.myEvents ? 0 : 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.calendar),
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    selected: selectedView == _ViewMode.calendar,
                    onSelected: (selected) {
                      if (selected) onViewChanged(_ViewMode.calendar);
                    },
                    selectedColor: AppColors.primaryIndigo,
                    labelStyle: TextStyle(
                      color: selectedView == _ViewMode.calendar
                          ? Colors.white
                          : const Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: const Color(0xFF2C3E50),
                      width: selectedView == _ViewMode.calendar ? 0 : 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterChipsDelegate oldDelegate) {
    return selectedView != oldDelegate.selectedView ||
        myTerminology != oldDelegate.myTerminology;
  }
}

// Week banner delegate for simple date display
class _WeekBannerDelegate extends SliverPersistentHeaderDelegate {
  final String weekLabel;
  final ThemeData theme;

  _WeekBannerDelegate({
    required this.weekLabel,
    required this.theme,
  });

  @override
  double get minExtent => 40.0;

  @override
  double get maxExtent => 40.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              weekLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_WeekBannerDelegate oldDelegate) {
    return weekLabel != oldDelegate.weekLabel;
  }
}

// Roles section with segmented control navigation
class _RolesSection extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  final List<Map<String, dynamic>> availability;
  final Widget profileMenu;
  final VoidCallback? onHideBottomBar;
  final VoidCallback? onShowBottomBar;
  final VoidCallback? onTitleTap;
  final ValueNotifier<int>? resetToMyShifts;

  const _RolesSection({
    required this.events,
    required this.userKey,
    required this.loading,
    required this.availability,
    required this.profileMenu,
    this.onHideBottomBar,
    this.onShowBottomBar,
    this.onTitleTap,
    this.resetToMyShifts,
  });

  @override
  State<_RolesSection> createState() => _RolesSectionState();
}

class _RolesSectionState extends State<_RolesSection> {
  _ViewMode _selectedView = _ViewMode.available;
  String? _currentWeekLabel;
  DateTime _selectedWeekStart = DateTime.now();
  bool _hideUnavailableDates = true; // Default: hide unavailable dates
  bool _didInitializeLabel = false;
  bool _showToggle = true; // Controls visibility of "hide unavailable dates" toggle
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.resetToMyShifts?.addListener(_onResetToMyShifts);
    _loadFilterPreference();
  }

  @override
  void dispose() {
    widget.resetToMyShifts?.removeListener(_onResetToMyShifts);
    super.dispose();
  }

  void _onResetToMyShifts() {
    if (mounted) {
      setState(() => _selectedView = _ViewMode.myEvents);
    }
  }

  /// Handles scroll notifications from child scrollable widgets
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      final scrollingDown = currentOffset > _lastScrollOffset;
      final scrollingUp = currentOffset < _lastScrollOffset;

      // Only trigger if scrolled more than 10 pixels to avoid jitter
      if ((currentOffset - _lastScrollOffset).abs() > 10) {
        if (scrollingDown && _showToggle && currentOffset > 50) {
          setState(() => _showToggle = false);
        } else if (scrollingUp && !_showToggle) {
          setState(() => _showToggle = true);
        }
        _lastScrollOffset = currentOffset;
      }
    }
    return false; // Don't stop notification propagation
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitializeLabel) {
      _updateWeekLabel();
      _didInitializeLabel = true;
    }
  }

  // Get the start of the week (Monday) for a given date
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday; // Monday = 1, Sunday = 7
    return date.subtract(Duration(days: weekday - 1));
  }

  // Format week label for navigation banner based on selected week
  String _getWeekNavigationLabel(DateTime weekStart) {
    final now = DateTime.now();
    final currentWeekStart = _getWeekStart(now);

    // Compare dates (ignoring time)
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final currentWeekDate = DateTime(currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);

    if (weekStartDate == currentWeekDate) {
      return AppLocalizations.of(context)!.thisWeek;
    } else if (weekStartDate == currentWeekDate.add(const Duration(days: 7))) {
      return AppLocalizations.of(context)!.nextWeek;
    } else if (weekStartDate == currentWeekDate.subtract(const Duration(days: 7))) {
      return AppLocalizations.of(context)!.lastWeek;
    } else {
      // Format as "Jan 6-12, 2025"
      final weekEnd = weekStart.add(const Duration(days: 6));
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final startMonth = months[weekStart.month - 1];
      final endMonth = months[weekEnd.month - 1];

      if (weekStart.month == weekEnd.month) {
        return '$startMonth ${weekStart.day}-${weekEnd.day}, ${weekStart.year}';
      } else {
        return '$startMonth ${weekStart.day}-$endMonth ${weekEnd.day}, ${weekStart.year}';
      }
    }
  }

  // Update the week label
  void _updateWeekLabel() {
    setState(() {
      _selectedWeekStart = _getWeekStart(_selectedWeekStart);
      _currentWeekLabel = _getWeekNavigationLabel(_selectedWeekStart);
    });
  }

  Future<void> _loadFilterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final hideUnavailable = prefs.getBool('filter_unavailable_dates') ?? true;
    if (mounted) {
      setState(() {
        _hideUnavailableDates = hideUnavailable;
      });
    }
  }

  Future<void> _saveFilterPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('filter_unavailable_dates', value);
  }

  // Check if an event conflicts with user's unavailability
  bool _hasAvailabilityConflict(Map<String, dynamic> event, String? userKey) {
    if (userKey == null || widget.availability.isEmpty) return false;

    // Get event date (YYYY-MM-DD format)
    final eventDateStr = event['date']?.toString();
    if (eventDateStr == null || eventDateStr.isEmpty) return false;

    // Parse event date to ensure it's in YYYY-MM-DD format
    final eventDate = _parseDateSafe(eventDateStr);
    if (eventDate == null) return false;
    final eventDateFormatted = '${eventDate.year.toString().padLeft(4, '0')}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';

    // Find unavailability records for this date
    final unavailableForDay = widget.availability.where((avail) {
      return avail['date'] == eventDateFormatted &&
             avail['status'] == 'unavailable';
    }).toList();

    if (unavailableForDay.isEmpty) return false; // No unavailability = no conflict

    // Get event time range if it exists
    final eventStartTime = event['start_time']?.toString();
    final eventEndTime = event['end_time']?.toString();

    // If event doesn't have specific times, check for full-day unavailability
    if (eventStartTime == null || eventEndTime == null ||
        eventStartTime.isEmpty || eventEndTime.isEmpty) {
      // Event has no time specified, any unavailability on this day is a conflict
      return true;
    }

    // Check time overlap with each unavailability period
    for (final avail in unavailableForDay) {
      final availStart = avail['startTime']?.toString();
      final availEnd = avail['endTime']?.toString();

      if (availStart != null && availEnd != null &&
          availStart.isNotEmpty && availEnd.isNotEmpty) {
        if (_checkTimeOverlap(eventStartTime, eventEndTime, availStart, availEnd)) {
          return true; // Found a time conflict
        }
      }
    }

    return false; // No time conflicts found
  }

  // Check if two time ranges overlap (HH:mm format)
  bool _checkTimeOverlap(String start1, String end1, String start2, String end2) {
    try {
      // Convert HH:mm to minutes since midnight for easier comparison
      int timeToMinutes(String time) {
        final parts = time.split(':');
        if (parts.length != 2) return 0;
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        return hours * 60 + minutes;
      }

      final start1Min = timeToMinutes(start1);
      final end1Min = timeToMinutes(end1);
      final start2Min = timeToMinutes(start2);
      final end2Min = timeToMinutes(end2);

      // Check for overlap: ranges overlap if start1 < end2 AND start2 < end1
      return start1Min < end2Min && start2Min < end1Min;
    } catch (e) {
      debugPrint('Error checking time overlap: $e');
      return true; // On error, assume conflict to be safe
    }
  }

  DateTime? _parseDateSafe(String input) {
    try {
      final iso = DateTime.tryParse(input);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    } catch (_) {}
    final us = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$').firstMatch(input);
    if (us != null) {
      final m = int.tryParse(us.group(1) ?? '');
      final d = int.tryParse(us.group(2) ?? '');
      var y = int.tryParse(us.group(3) ?? '');
      if (m != null && d != null && y != null) {
        if (y < 100) y += 2000;
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    final ymd = RegExp(
      r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$',
    ).firstMatch(input);
    if (ymd != null) {
      final y = int.tryParse(ymd.group(1) ?? '');
      final m = int.tryParse(ymd.group(2) ?? '');
      final d = int.tryParse(ymd.group(3) ?? '');
      if (y != null && m != null && d != null) {
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    return null;
  }

  List<RoleSummary> _computeRoleSummaries() {
    final Map<String, List<Map<String, dynamic>>> roleToEvents = {};
    final Map<String, int> roleToNeeded = {};
    final Map<String, int?> roleToRemaining = {};
    // Exclude events the current user already accepted and past events
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sourceEvents = widget.events.where((e) {
      if (isAcceptedByUser(e, widget.userKey)) return false;
      // Filter out past events
      final dateStr = e['date']?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        final eventDate = _parseDateSafe(dateStr);
        if (eventDate != null && eventDate.isBefore(today)) {
          return false; // Exclude past events
        }
      }
      // Filter out events on unavailable dates (if toggle is ON)
      if (_hideUnavailableDates && _hasAvailabilityConflict(e, widget.userKey)) {
        return false; // Exclude events that conflict with unavailability
      }
      return true;
    });
    debugPrint(
      '📋 Computing role summaries: ${widget.events.length} total events, ${sourceEvents.length} available (filtered out accepted, past${_hideUnavailableDates ? ', and unavailable dates' : ''})',
    );
    for (final e in sourceEvents) {
      final stats = e['role_stats'];
      if (stats is List && stats.isNotEmpty) {
        for (final stat in stats) {
          if (stat is Map) {
            final role = stat['role']?.toString() ?? '';
            final remaining = int.tryParse(stat['remaining']?.toString() ?? '');
            if (role.isNotEmpty) {
              roleToEvents.putIfAbsent(role, () => []).add(e);
              roleToRemaining[role] =
                  (roleToRemaining[role] ?? 0)! + (remaining ?? 0);
            }
          }
        }
      } else {
        final roles = e['roles'];
        if (roles is List) {
          for (final r in roles) {
            if (r is Map) {
              final role = r['role']?.toString() ?? '';
              final count = int.tryParse(r['count']?.toString() ?? '');
              if (role.isNotEmpty && count != null) {
                roleToEvents.putIfAbsent(role, () => []).add(e);
                roleToNeeded[role] = (roleToNeeded[role] ?? 0) + count;
              }
            }
          }
        }
      }
    }
    final summaries = roleToEvents.entries.map((e) {
      return RoleSummary(
        roleName: e.key,
        totalNeeded: roleToNeeded[e.key] ?? 0,
        eventCount: e.value.length,
        events: e.value,
        remainingTotal: roleToRemaining[e.key],
      );
    }).toList()..sort((a, b) => b.eventCount.compareTo(a.eventCount));

    debugPrint(
      '🔍 Showing ${summaries.length} roles after filtering past/accepted events',
    );
    return summaries;
  }

  List<Map<String, dynamic>> _getMyAcceptedEvents() {
    if (widget.userKey == null) return const [];
    final List<Map<String, dynamic>> mine = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    debugPrint('[MY_EVENTS] Filtering ${widget.events.length} events for user ${widget.userKey}');
    debugPrint('[MY_EVENTS] Today date: $today');

    for (final e in widget.events) {
      final eventId = e['_id'] ?? e['id'];
      final eventName = e['event_name'] ?? e['title'] ?? 'Unknown';

      final isAccepted = isAcceptedByUser(e, widget.userKey);
      debugPrint('[MY_EVENTS] Processing event: $eventId - $eventName (accepted: $isAccepted)');

      // Only include if accepted AND event is today or in the future
      if (isAccepted) {
        final eventDate = _parseDateSafe(e['date']?.toString() ?? '');
        debugPrint('[MY_EVENTS] Event ${e['_id']} (${e['event_name']}): date=$eventDate, today=$today, isBefore=${eventDate?.isBefore(today)}');
        if (eventDate != null && !eventDate.isBefore(today)) {
          mine.add(e);
          debugPrint('[MY_EVENTS] ✓ Added event ${e['_id']} to My Events');
        } else {
          debugPrint('[MY_EVENTS] ✗ Skipped event ${e['_id']} - date in past or null');
        }
      }
    }

    debugPrint('[MY_EVENTS] Final count: ${mine.length} events');
    return mine;
  }

  int _parseTimeMinutes(String? raw) {
    if (raw == null) return 0;
    final s = raw.trim();
    if (s.isEmpty) return 0;
    final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$').firstMatch(s);
    if (m == null) return 0;
    int hour = int.tryParse(m.group(1) ?? '0') ?? 0;
    final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ampm = m.group(3);
    if (ampm != null) {
      final u = ampm.toUpperCase();
      if (u == 'AM') {
        if (hour == 12) hour = 0;
      } else if (u == 'PM') {
        if (hour != 12) hour += 12;
      }
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return 0;
    return hour * 60 + minute;
  }

  int _calculateTotalHours(List<Map<String, dynamic>> events) {
    int totalMinutes = 0;
    for (final e in events) {
      final startMins = _parseTimeMinutes(e['start_time']?.toString());
      final endMins = _parseTimeMinutes(e['end_time']?.toString());
      if (startMins > 0 && endMins > startMins) {
        totalMinutes += (endMins - startMins);
      }
    }
    return (totalMinutes / 60).round();
  }

  String _getWeekLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    final diff = eventDate.difference(today).inDays;

    if (diff >= 0 && diff < 7) {
      return AppLocalizations.of(context)!.thisWeek;
    } else if (diff >= 7 && diff < 14) {
      return AppLocalizations.of(context)!.nextWeek;
    } else if (diff >= 14 && diff < 21) {
      return AppLocalizations.of(context)!.in2Weeks;
    } else if (diff >= 21 && diff < 28) {
      return AppLocalizations.of(context)!.in3Weeks;
    } else {
      final formatter = DateFormat('MMM d');
      return 'Week of ${formatter.format(date)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terminologyProvider = context.watch<TerminologyProvider>();
    terminologyProvider.updateSystemLanguage(context);

    // DEBUG: Log incoming events
    debugPrint('🔍 [ROLES_SECTION] Building with ${widget.events.length} events, userKey=${widget.userKey}, loading=${widget.loading}');

    final roleSummaries = _computeRoleSummaries();
    final availableCount = roleSummaries.length;

    // DEBUG: Log computed summaries
    debugPrint('🔍 [ROLES_SECTION] Computed ${roleSummaries.length} role summaries');
    final totalPositions = roleSummaries.fold<int>(
      0,
      (sum, role) => sum + role.totalNeeded,
    );

    // Get My Events statistics
    final myEvents = _getMyAcceptedEvents();
    final myEventsCount = myEvents.length;
    final myEventsTotalHours = _calculateTotalHours(myEvents);

    // Dynamic title based on selected view (no subtitle in new compact design)
    final String appBarTitle = terminologyProvider.plural;

    // Calculate header heights - account for safe area (notch/Dynamic Island)
    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final double appBarHeight = safeAreaTop + 56.0; // Safe area + content height
    const double chipsHeight = 60.0;
    // toggleHeight removed — the filter icon is inline inside the chips row, not a separate row
    final double totalHeaderHeight = appBarHeight + chipsHeight;

    // Banner height: accounts for free-month/expired banner below chips
    final subscriptionService = SubscriptionService();
    const double bannerHeight40 = 40.0;
    final bool showFreeBanner = subscriptionService.statusLoaded &&
        (subscriptionService.isReadOnly || subscriptionService.isInFreeMonth);
    final double bannerHeight = showFreeBanner ? bannerHeight40 : 0.0;
    final double totalSpacerHeight = totalHeaderHeight + bannerHeight;

    // Build content widget based on selected view
    Widget content;
    switch (_selectedView) {
      case _ViewMode.available:
        content = _RoleList(
          summaries: roleSummaries,
          loading: widget.loading,
          allEvents: widget.events,
          userKey: widget.userKey,
          availability: widget.availability,
          headerHeight: totalSpacerHeight,
        );
        break;
      case _ViewMode.myEvents:
        content = _MyEventsList(
          events: widget.events,
          userKey: widget.userKey,
          loading: widget.loading,
          onHideBottomBar: widget.onHideBottomBar,
          onShowBottomBar: widget.onShowBottomBar,
          availability: widget.availability,
          headerHeight: totalSpacerHeight,
        );
        break;
      case _ViewMode.calendar:
        content = _CalendarTab(
          events: widget.events,
          userKey: widget.userKey,
          loading: widget.loading,
          availability: widget.availability,
          headerHeight: totalSpacerHeight,
        );
        break;
    }

    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        // Full-screen scrollable content (starts from top:0 to scroll behind headers)
        // Wrapped in NotificationListener to detect scroll and hide toggle
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: content,
          ),
        ),

        // Floating transparent headers on top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact app bar with blur
              Container(
                height: appBarHeight,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.navySpaceCadet.withValues(alpha: 0.92),
                            AppColors.oceanBlue.withValues(alpha: 0.88),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: safeAreaTop + 8, // Safe area + extra padding
                          left: 20,
                          right: 20,
                          bottom: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selectedView = _ViewMode.myEvents);
                                },
                                child: Text(
                                  appBarTitle,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            widget.profileMenu,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter chips with blur
              SizedBox(
                height: chipsHeight,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.available),
                            avatar: Icon(
                              Icons.work_outline,
                              size: 18,
                              color: _selectedView == _ViewMode.available
                                  ? AppColors.navySpaceCadet
                                  : AppColors.textMuted,
                            ),
                            selected: _selectedView == _ViewMode.available,
                            onSelected: (selected) {
                              if (selected) setState(() {
                                _selectedView = _ViewMode.available;
                                _showToggle = true; // Reset toggle visibility
                                _lastScrollOffset = 0;
                              });
                            },
                            backgroundColor: Colors.white.withOpacity(0.7),
                            selectedColor: AppColors.primaryIndigo,
                            labelStyle: TextStyle(
                              color: _selectedView == _ViewMode.available
                                  ? AppColors.navySpaceCadet
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: _selectedView == _ViewMode.available
                                  ? AppColors.oceanBlue
                                  : AppColors.borderGrey,
                              width: _selectedView == _ViewMode.available ? 1.5 : 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(terminologyProvider.my),
                            avatar: Icon(
                              Icons.event,
                              size: 18,
                              color: _selectedView == _ViewMode.myEvents
                                  ? AppColors.navySpaceCadet
                                  : AppColors.textMuted,
                            ),
                            selected: _selectedView == _ViewMode.myEvents,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedView = _ViewMode.myEvents);
                            },
                            backgroundColor: Colors.white.withOpacity(0.7),
                            selectedColor: AppColors.primaryIndigo,
                            labelStyle: TextStyle(
                              color: _selectedView == _ViewMode.myEvents
                                  ? AppColors.navySpaceCadet
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: _selectedView == _ViewMode.myEvents
                                  ? AppColors.oceanBlue
                                  : AppColors.borderGrey,
                              width: _selectedView == _ViewMode.myEvents ? 1.5 : 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppLocalizations.of(context)!.calendar),
                            avatar: Icon(
                              Icons.calendar_month,
                              size: 18,
                              color: _selectedView == _ViewMode.calendar
                                  ? AppColors.navySpaceCadet
                                  : AppColors.textMuted,
                            ),
                            selected: _selectedView == _ViewMode.calendar,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedView = _ViewMode.calendar);
                            },
                            backgroundColor: Colors.white.withOpacity(0.7),
                            selectedColor: AppColors.primaryIndigo,
                            labelStyle: TextStyle(
                              color: _selectedView == _ViewMode.calendar
                                  ? AppColors.navySpaceCadet
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: _selectedView == _ViewMode.calendar
                                  ? AppColors.oceanBlue
                                  : AppColors.borderGrey,
                              width: _selectedView == _ViewMode.calendar ? 1.5 : 1,
                            ),
                          ),
                          // Inline unavailable-dates filter (only in Available view)
                          if (_selectedView == _ViewMode.available) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _hideUnavailableDates = !_hideUnavailableDates;
                                });
                                _saveFilterPreference(_hideUnavailableDates);
                              },
                              child: Tooltip(
                                message: _hideUnavailableDates
                                    ? 'Showing only available dates'
                                    : 'Showing all dates',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _hideUnavailableDates
                                        ? AppColors.primaryIndigo.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _hideUnavailableDates
                                          ? AppColors.oceanBlue
                                          : AppColors.borderGrey,
                                      width: _hideUnavailableDates ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Icon(
                                    _hideUnavailableDates
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 16,
                                    color: _hideUnavailableDates
                                        ? AppColors.navySpaceCadet
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                  ),  // BackdropFilter
                ),    // ClipRect
              ),      // SizedBox
              // Free month / expired subscription banner — below chips, above content
              const FreeMonthBanner(),
            ],
          ),
        ),


      ],
    );
  }
}

class _MyEventsList extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  final Function(String)? onWeekChanged;
  final VoidCallback? onHideBottomBar;
  final VoidCallback? onShowBottomBar;
  final List<Map<String, dynamic>> availability;
  final double headerHeight;

  const _MyEventsList({
    required this.events,
    required this.userKey,
    required this.loading,
    this.onWeekChanged,
    this.onHideBottomBar,
    this.onShowBottomBar,
    this.availability = const [],
    this.headerHeight = 160.0,
  });

  @override
  State<_MyEventsList> createState() => _MyEventsListState();
}

class _MyEventsListState extends State<_MyEventsList> {
  final ScrollController _scrollController = ScrollController();
  Map<String, List<Map<String, dynamic>>> _weekGroups = {};
  List<String> _weekKeys = [];
  String? _currentVisibleWeek;
  bool _didInitializeWeeks = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitializeWeeks) {
      _updateWeekGroups();
      _didInitializeWeeks = true;
    }
  }

  @override
  void didUpdateWidget(_MyEventsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if events actually changed
    if (oldWidget.events != widget.events) {
      _updateWeekGroups();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_weekKeys.isEmpty || !_scrollController.hasClients) return;

    // Calculate which week is currently visible based on scroll position
    final scrollOffset = _scrollController.offset;

    // Calculate positions for each week section
    double currentPosition = 0;

    for (int i = 0; i < _weekKeys.length; i++) {
      final weekKey = _weekKeys[i];
      final weekEvents = _weekGroups[weekKey] ?? [];

      // Each week section has: header (~60px) + events (~140px each) + spacing
      final weekHeight = 60 + (weekEvents.length * 140) + 20;

      if (scrollOffset <= currentPosition + weekHeight) {
        // This week is at the top of the visible area
        // Only update if it's different from current
        if (_currentVisibleWeek != weekKey) {
          _currentVisibleWeek = weekKey;
          widget.onWeekChanged?.call(weekKey);
        }
        break;
      }
      currentPosition += weekHeight;
    }
  }

  void _updateWeekGroups() {
    final mine = _filterMyAccepted();
    _weekGroups = _groupEventsByWeek(mine);

    // Sort week keys
    final preferredOrder = [AppLocalizations.of(context)!.thisWeek, AppLocalizations.of(context)!.nextWeek];
    _weekKeys = _weekGroups.keys.toList()
      ..sort((a, b) {
        final aIndex = preferredOrder.indexOf(a);
        final bIndex = preferredOrder.indexOf(b);
        if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;

        // For date-based labels, parse and compare
        final aEvents = _weekGroups[a]!;
        final bEvents = _weekGroups[b]!;
        if (aEvents.isNotEmpty && bEvents.isNotEmpty) {
          final aDate = _parseDateSafe(aEvents.first['date']?.toString() ?? '');
          final bDate = _parseDateSafe(bEvents.first['date']?.toString() ?? '');
          if (aDate != null && bDate != null) {
            return aDate.compareTo(bDate);
          }
        }
        return a.compareTo(b);
      });

    // Only set initial week label if not already set
    if (_weekKeys.isNotEmpty && _currentVisibleWeek == null) {
      _currentVisibleWeek = _weekKeys.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onWeekChanged?.call(_currentVisibleWeek!);
      });
    }
  }

  List<Map<String, dynamic>> _filterMyAccepted() {
    if (widget.userKey == null) return const [];
    final List<Map<String, dynamic>> mine = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final e in widget.events) {
      if (isAcceptedByUser(e, widget.userKey)) {
        final eventDate = _parseDateSafe(e['date']?.toString() ?? '');
        if (eventDate != null && !eventDate.isBefore(today)) {
          mine.add(e);
        }
      }
    }
    return mine;
  }

  int _parseTimeMinutes(String? raw) {
    if (raw == null) return 0;
    final s = raw.trim();
    if (s.isEmpty) return 0;
    final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$').firstMatch(s);
    if (m == null) return 0;
    int hour = int.tryParse(m.group(1) ?? '0') ?? 0;
    final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ampm = m.group(3);
    if (ampm != null) {
      final u = ampm.toUpperCase();
      if (u == 'AM') {
        if (hour == 12) hour = 0;
      } else if (u == 'PM') {
        if (hour != 12) hour += 12;
      }
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return 0;
    return hour * 60 + minute;
  }

  int _calculateTotalHours(List<Map<String, dynamic>> events) {
    int totalMinutes = 0;
    for (final e in events) {
      final startMins = _parseTimeMinutes(e['start_time']?.toString());
      final endMins = _parseTimeMinutes(e['end_time']?.toString());
      if (startMins > 0 && endMins > startMins) {
        totalMinutes += (endMins - startMins);
      }
    }
    return (totalMinutes / 60).round();
  }

  Map<String, List<Map<String, dynamic>>> _groupEventsByWeek(
    List<Map<String, dynamic>> events,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();

    final monthNames = [
      l10n.january,
      l10n.february,
      l10n.march,
      l10n.april,
      l10n.may,
      l10n.june,
      l10n.july,
      l10n.august,
      l10n.september,
      l10n.october,
      l10n.november,
      l10n.december,
    ];

    for (final event in events) {
      final dateStr = event['date']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;

      final eventDate = _parseDateSafe(dateStr);
      if (eventDate == null) continue;

      // Group by month name (+ year if not current year)
      final monthLabel = eventDate.year == now.year
          ? monthNames[(eventDate.month - 1).clamp(0, 11)]
          : '${monthNames[(eventDate.month - 1).clamp(0, 11)]} ${eventDate.year}';

      grouped.putIfAbsent(monthLabel, () => []);
      grouped[monthLabel]!.add(event);
    }

    return grouped;
  }

  DateTime? _parseDateSafe(String input) {
    try {
      final iso = DateTime.tryParse(input);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    } catch (_) {}
    final us = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$').firstMatch(input);
    if (us != null) {
      final m = int.tryParse(us.group(1) ?? '');
      final d = int.tryParse(us.group(2) ?? '');
      var y = int.tryParse(us.group(3) ?? '');
      if (m != null && d != null && y != null) {
        if (y < 100) y += 2000;
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    final ymd = RegExp(
      r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$',
    ).firstMatch(input);
    if (ymd != null) {
      final y = int.tryParse(ymd.group(1) ?? '');
      final m = int.tryParse(ymd.group(2) ?? '');
      final d = int.tryParse(ymd.group(3) ?? '');
      if (y != null && m != null && d != null) {
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = _filterMyAccepted();

    return EnhancedRefreshIndicator(
      showLastRefreshTime: false,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Transparent spacer that scrolls behind headers
          SliverToBoxAdapter(
            child: Container(
              height: widget.headerHeight, // AppBar + Chips + banner
              color: Colors.transparent,
            ),
          ),
          if (mine.isEmpty && !widget.loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildEmptyState(theme),
              ),
            ),
          if (mine.isNotEmpty) ..._buildWeeklySections(theme, mine),
          // View Past Events button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100), // Added bottom padding for nav bar
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final events = context.read<DataService>().events;
                    debugPrint('🚀 [NAVIGATION] Opening PastEventsPage with ${events.length} events');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PastEventsPage(events: events, userKey: widget.userKey),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'View Past Events',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeklySections(
    ThemeData theme,
    List<Map<String, dynamic>> events,
  ) {
    final grouped = _groupEventsByWeek(events);
    final List<Widget> sections = [];

    // Sort events within each group by date (earliest first)
    grouped.forEach((weekLabel, weekEvents) {
      weekEvents.sort((a, b) {
        final dateA = _parseDateSafe(a['date']?.toString() ?? '');
        final dateB = _parseDateSafe(b['date']?.toString() ?? '');
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });
    });

    // Sort month labels by earliest event date in each group
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final aEvents = grouped[a]!;
        final bEvents = grouped[b]!;
        if (aEvents.isNotEmpty && bEvents.isNotEmpty) {
          final aDate = _parseDateSafe(aEvents.first['date']?.toString() ?? '');
          final bDate = _parseDateSafe(bEvents.first['date']?.toString() ?? '');
          if (aDate != null && bDate != null) {
            return aDate.compareTo(bDate);
          }
        }
        return a.compareTo(b);
      });

    for (int i = 0; i < sortedKeys.length; i++) {
      final weekLabel = sortedKeys[i];
      final weekEvents = grouped[weekLabel]!;

      // Add week header text
      sections.add(
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(20, i == 0 ? 12 : 24, 20, 8),
            child: Text(
              weekLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );

      // Add events for this week
      sections.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= weekEvents.length) return null;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                index == 0 ? 12 : 8, // Add more space for first item
                20,
                index == weekEvents.length - 1 ? 12 : 8, // Add more space for last item
              ),
              child: _buildEventCard(context, theme, weekEvents[index]),
            );
          }, childCount: weekEvents.length),
        ),
      );
    }

    return sections;
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final terminologyProvider = context.watch<TerminologyProvider>();

    return Column(
      children: [
        const SizedBox(height: 24),
        Image.asset(
          'assets/my_shifts_empty.png',
          height: 220,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.noAcceptedTerminology(terminologyProvider.plural.toLowerCase()),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.navySpaceCadet,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.acceptTerminologyFromRoles(terminologyProvider.plural.toLowerCase()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> e, {
    String? roleNameOverride,
  }) {
    final eventName = e['event_name']?.toString() ?? 'Untitled Event';
    final clientName = e['client_name']?.toString() ?? '';
    final venue = e['venue_name']?.toString() ?? '';
    final venueAddress = e['venue_address']?.toString() ?? '';
    final rawMaps = e['google_maps_url']?.toString() ?? '';
    final googleMapsUrl = rawMaps.isNotEmpty
        ? rawMaps
        : (venueAddress.isNotEmpty ? venueAddress : venue);
    final date = e['date']?.toString() ?? '';

    String? role;
    bool isConfirmed = false;
    if (roleNameOverride != null && roleNameOverride.trim().isNotEmpty) {
      role = roleNameOverride.trim();
      final acceptedEntry = findAcceptedStaffEntry(e, widget.userKey);
      if (acceptedEntry != null) {
        final response = acceptedEntry['response']?.toString().toLowerCase();
        isConfirmed = response == null || response == 'accept' || response == 'accepted';
      }
    } else {
      final acceptedEntry = findAcceptedStaffEntry(e, widget.userKey);
      if (acceptedEntry != null) {
        role = acceptedEntry['role']?.toString();
        final response = acceptedEntry['response']?.toString().toLowerCase();
        isConfirmed = response == null || response == 'accept' || response == 'accepted';
      }
    }

    // Check if event is private (invitation)
    final visibilityType = e['visibilityType']?.toString() ?? '';
    final isPrivate = visibilityType == 'private';

    // Calculate estimated earnings
    String? estimatedPay;
    final start = e['start_time']?.toString() ?? '';
    final end = e['end_time']?.toString() ?? '';
    final startMins = _parseTimeMinutes(start);
    final endMins = _parseTimeMinutes(end);

    if (role != null && role.isNotEmpty && startMins > 0 && endMins > startMins) {
      final roles = e['roles'];
      if (roles is List) {
        for (final r in roles) {
          if (r is Map && (r['role']?.toString() ?? '') == role) {
            final tariff = r['tariff'];
            if (tariff is Map) {
              final rate = tariff['rate']?.toString();
              final currency = tariff['currency']?.toString() ?? '\$';
              final rateValue = double.tryParse(rate ?? '');
              if (rateValue != null) {
                final hours = (endMins - startMins) / 60.0;
                final total = hours * rateValue;
                estimatedPay = '$currency${total.toStringAsFixed(0)}';
              }
            }
            break;
          }
        }
      }
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surfaceLight,
            border: Border.all(
              color: AppColors.purpleLight.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purpleLight.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventDetailPage(
                      event: e,
                      roleName: role,
                      showRespondActions: false,
                      acceptedEvents: _filterMyAccepted(),
                      availability: widget.availability,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isConfirmed
                                  ? [
                                      Colors.green.shade400,
                                      Colors.green.shade600,
                                    ]
                                  : (isPrivate
                                      ? [
                                          AppColors.purple,
                                          const Color(0xFF7E22CE),
                                        ]
                                      : [
                                          AppColors.purpleLight,
                                          const Color(0xFFEC4899),
                                        ]),
                            ),
                            shape: BoxShape.circle,
                            boxShadow: isConfirmed
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : (isPrivate
                                    ? [
                                        BoxShadow(
                                          color: AppColors.purple.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (role != null && role.isNotEmpty)
                                ? role
                                : (clientName.isNotEmpty
                                      ? clientName
                                      : eventName),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isConfirmed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Confirmed',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (venueAddress.isNotEmpty ||
                        googleMapsUrl.isNotEmpty ||
                        (venue.isNotEmpty &&
                            venue.toLowerCase() !=
                                eventName.toLowerCase())) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  if (venue.isNotEmpty &&
                                      venue.toLowerCase() !=
                                          eventName.toLowerCase()) ...[
                                    TextSpan(
                                      text: venue,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    if (venueAddress.isNotEmpty)
                                      TextSpan(
                                        text: '\n$venueAddress',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                  ] else if (venueAddress.isNotEmpty)
                                    TextSpan(
                                      text: venueAddress,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (googleMapsUrl.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _launchMapUrl(googleMapsUrl),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.map_outlined,
                                      size: 14,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // DATE & TIME - Highlighted prominently
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: isConfirmed
                                  ? Colors.green.shade600.withOpacity(0.5) // Green for confirmed
                                  : (isPrivate
                                      ? AppColors.purple // Purple for invitations
                                      : Colors.blue.shade600), // Blue for available
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatEventDateTimeLabel(
                                  dateStr: date,
                                  startTimeStr: e['start_time']?.toString(),
                                  endTimeStr: e['end_time']?.toString(),
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (clientName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      // Client name - Highlighted
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? Colors.green.shade50.withOpacity(0.5) // Soft green for confirmed
                              : (isPrivate
                                  ? const Color(0xFFF3E8FF) // Soft purple for invitations
                                  : const Color(0xFFEEF2FF)), // Light blue for available
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 14,
                              color: isConfirmed
                                  ? Colors.green.shade600.withOpacity(0.5) // Green for confirmed
                                  : (isPrivate
                                      ? AppColors.purple // Purple for invitations
                                      : Colors.blue.shade600), // Blue for available
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  children: [
                                    TextSpan(text: AppLocalizations.of(context)!.clientLabel),
                                    TextSpan(
                                      text: clientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (estimatedPay != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isConfirmed
                                      ? Colors.green.shade100 // Green for confirmed
                                      : (isPrivate
                                          ? const Color(0xFFF3E8FF) // Purple for invitations
                                          : Colors.blue.shade100), // Blue for available
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  estimatedPay,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isConfirmed
                                        ? Colors.green.shade700 // Green for confirmed
                                        : (isPrivate
                                            ? AppColors.purple // Purple for invitations
                                            : Colors.blue.shade700), // Blue for available
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        // Decorative triangle in bottom right corner
        Positioned(
          right: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(16),
            ),
            child: CustomPaint(
              size: const Size(40, 40),
              painter: _TrianglePainter(
                color: isConfirmed
                    ? Colors.green.shade100.withOpacity(0.6)
                    : Colors.grey.shade100.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for the triangle decoration
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width, 0); // Top right
    path.lineTo(size.width, size.height); // Bottom right
    path.lineTo(0, size.height); // Bottom left
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RoleList extends StatelessWidget {
  final List<RoleSummary> summaries;
  final bool loading;
  final List<Map<String, dynamic>> allEvents;
  final String? userKey;
  final List<Map<String, dynamic>> availability;
  final double headerHeight;

  const _RoleList({
    required this.summaries,
    required this.loading,
    required this.allEvents,
    required this.userKey,
    this.availability = const [],
    this.headerHeight = 194.0,
  });

  List<Map<String, dynamic>> _acceptedEventsForUser(
    List<Map<String, dynamic>> events,
    String? userKey,
  ) {
    if (userKey == null) return const [];
    final List<Map<String, dynamic>> result = [];
    for (final e in events) {
      if (isAcceptedByUser(e, userKey)) {
        result.add(e);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hide roles that are full (remainingTotal == 0) when backend provides role_stats
    final display = summaries
        .where((s) => s.remainingTotal == null || (s.remainingTotal ?? 0) > 0)
        .toList();

    // Build one card per (event, role) pair so roles are explicit
    final List<Map<String, dynamic>> roleEventPairs = [];
    for (final summary in display) {
      final String roleName = summary.roleName;
      for (final e in summary.events) {
        roleEventPairs.add({'event': e, 'roleName': roleName});
      }
    }

    // Sort by event date
    roleEventPairs.sort((a, b) {
      final aDate = (a['event'] as Map<String, dynamic>)['date']?.toString() ?? '';
      final bDate = (b['event'] as Map<String, dynamic>)['date']?.toString() ?? '';
      return aDate.compareTo(bDate);
    });

    // Group events by month for headers
    final Map<String, List<Map<String, dynamic>>> eventsByMonth = {};
    for (final pair in roleEventPairs) {
      final event = pair['event'] as Map<String, dynamic>;
      final dateStr = event['date']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          eventsByMonth.putIfAbsent(monthKey, () => []).add(pair);
        } catch (e) {
          // If date parsing fails, add to "unknown" group
          eventsByMonth.putIfAbsent('unknown', () => []).add(pair);
        }
      } else {
        eventsByMonth.putIfAbsent('unknown', () => []).add(pair);
      }
    }

    if (roleEventPairs.isEmpty && !loading) {
      final l10n = AppLocalizations.of(context)!;
      final terminologyProvider = context.watch<TerminologyProvider>();

      return EnhancedRefreshIndicator(
        showLastRefreshTime: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/available_shifts_empty.png',
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noAvailableTerminology(terminologyProvider.plural),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navySpaceCadet,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        l10n.noTerminologyMatchProfile(terminologyProvider.plural.toLowerCase()),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return EnhancedRefreshIndicator(
      showLastRefreshTime: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Transparent spacer that scrolls behind headers
          SliverToBoxAdapter(
            child: Container(
              height: headerHeight, // AppBar + Chips + Toggle + banner
              color: Colors.transparent,
            ),
          ),
          if (roleEventPairs.isEmpty && !loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildEmptyState(context, theme),
              ),
            ),
          if (roleEventPairs.isNotEmpty)
            ...eventsByMonth.entries.map((monthEntry) {
              final monthKey = monthEntry.key;
              final monthEvents = monthEntry.value;

              // Format month header
              String monthLabel = AppLocalizations.of(context)!.noDate;
              if (monthKey != 'unknown') {
                try {
                  final parts = monthKey.split('-');
                  final year = int.parse(parts[0]);
                  final month = int.parse(parts[1]);
                  final date = DateTime(year, month);
                  monthLabel = DateFormat('MMMM yyyy').format(date);
                } catch (e) {
                  monthLabel = monthKey;
                }
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  // First item is the month header
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 20, 12),
                      child: Text(
                        monthLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }

                  // Adjust index for event cards (subtract 1 for header)
                  final eventIndex = index - 1;
                  if (eventIndex >= monthEvents.length) return null;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      eventIndex == monthEvents.length - 1 ? 8 : 8,
                    ),
                    child: _buildEventCard(
                      context,
                      theme,
                      monthEvents[eventIndex]['event'] as Map<String, dynamic>,
                      roleNameOverride:
                          monthEvents[eventIndex]['roleName'] as String,
                    ),
                  );
                }, childCount: monthEvents.length + 1), // +1 for header
              );
            }).toList(),
          // Bottom padding for navigation bar
          SliverToBoxAdapter(
            child: Container(
              height: 100, // Bottom padding for nav bar
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final terminologyProvider = context.watch<TerminologyProvider>();
    return Column(
      children: [
        const SizedBox(height: 24),
        Image.asset(
          'assets/available_shifts_empty.png',
          height: 220,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.noAvailableTerminology(terminologyProvider.plural),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.navySpaceCadet,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.noTerminologyMatchProfile(terminologyProvider.plural.toLowerCase()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // Removed obsolete _buildRoleCard since Roles tab now shows event cards.

  Widget _buildEventCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> e, {
    String? roleNameOverride,
  }) {
    final eventName = e['event_name']?.toString() ?? 'Untitled Event';
    final clientName = e['client_name']?.toString() ?? '';
    final venue = e['venue_name']?.toString() ?? '';
    final venueAddress = e['venue_address']?.toString() ?? '';
    final rawMaps = e['google_maps_url']?.toString() ?? '';
    final googleMapsUrl = rawMaps.isNotEmpty
        ? rawMaps
        : (venueAddress.isNotEmpty ? venueAddress : venue);
    final date = e['date']?.toString() ?? '';

    final userKey =
        (context.findAncestorStateOfType<_RootPageState>())?._userKey;

    String? role;
    bool isUserAccepted = false;
    if (roleNameOverride != null && roleNameOverride.trim().isNotEmpty) {
      role = roleNameOverride.trim();
    } else {
      final acceptedEntry = findAcceptedStaffEntry(e, userKey);
      if (acceptedEntry != null) {
        role = acceptedEntry['role']?.toString();
        isUserAccepted = true;
      }
    }

    // Show blue indicator for unconfirmed roles (when user hasn't accepted yet)
    final showBlueIndicator = !isUserAccepted;

    // Calculate estimated earnings
    String? estimatedPay;
    final start = e['start_time']?.toString() ?? '';
    final end = e['end_time']?.toString() ?? '';
    int? startMins;
    int? endMins;

    // Parse times using simple regex since _parseTimeMinutes is not accessible here
    int? parseTime(String? raw) {
      if (raw == null) return null;
      final s = raw.trim();
      if (s.isEmpty) return null;
      final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$').firstMatch(s);
      if (m == null) return null;
      int hour = int.tryParse(m.group(1) ?? '0') ?? 0;
      final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
      final ampm = m.group(3);
      if (ampm != null) {
        final u = ampm.toUpperCase();
        if (u == 'AM') {
          if (hour == 12) hour = 0;
        } else if (u == 'PM') {
          if (hour != 12) hour += 12;
        }
      }
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return hour * 60 + minute;
    }

    startMins = parseTime(start);
    endMins = parseTime(end);

    if (role != null && role.isNotEmpty && startMins != null && endMins != null && startMins > 0 && endMins > startMins) {
      final roles = e['roles'];
      if (roles is List) {
        for (final r in roles) {
          if (r is Map && (r['role']?.toString() ?? '') == role) {
            final tariff = r['tariff'];
            if (tariff is Map) {
              final rate = tariff['rate']?.toString();
              final currency = tariff['currency']?.toString() ?? '\$';
              final rateValue = double.tryParse(rate ?? '');
              if (rateValue != null) {
                final hours = (endMins - startMins) / 60.0;
                final total = hours * rateValue;
                estimatedPay = '$currency${total.toStringAsFixed(0)}';
              }
            }
            break;
          }
        }
      }
    }

    // Check if event is private
    final visibilityType = e['visibilityType']?.toString() ?? '';
    final isPrivate = visibilityType == 'private';

    // Soft off-white background for cards, purple borders for invitations
    final cardColor = AppColors.surfaceLight;

    final borderColor = isPrivate
        ? AppColors.purple.withOpacity(0.4)  // Purple border for private
        : AppColors.purpleLight.withOpacity(0.2);

    final shadowColor = isPrivate
        ? AppColors.purple.withOpacity(0.15)  // Purple shadow for private
        : AppColors.purpleLight.withOpacity(0.08);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: cardColor,
            border: Border.all(
              color: borderColor,
              width: isPrivate ? 1.5 : 1,  // Thicker border for private
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: isPrivate ? 16 : 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EventDetailPage(
                      event: e,
                      roleName: role,
                      acceptedEvents: _acceptedEventsForUser(
                        allEvents,
                        userKey,
                      ),
                      availability: availability,
                    ),
                  ),
                );
                // Data refresh is handled by EventDetailPage calling forceRefresh()
                // which triggers Consumer<DataService> to rebuild automatically
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: showBlueIndicator
                                ? (isPrivate
                                    ? AppColors.purple  // Pure purple for invitations
                                    : Colors.blue.shade500)
                                : const Color(0xFFEC4899),
                            shape: BoxShape.circle,
                            boxShadow: showBlueIndicator
                                ? [
                                    BoxShadow(
                                      color: (isPrivate
                                          ? AppColors.purple
                                          : Colors.blue).withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  (role != null && role.isNotEmpty)
                                      ? role
                                      : (clientName.isNotEmpty
                                            ? clientName
                                            : eventName),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (isPrivate) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.purple.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.purple.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock,
                                        size: 10,
                                        color: AppColors.purple,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        AppLocalizations.of(context)!.private,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPrivate
                                ? Colors.white
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPrivate
                                  ? AppColors.purple.withOpacity(0.3)
                                  : Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPrivate ? Icons.mail_outline : Icons.schedule,
                                size: 14,
                                color: isPrivate
                                    ? AppColors.purple
                                    : Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPrivate ? AppLocalizations.of(context)!.invitation : 'Available',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isPrivate
                                      ? AppColors.purple
                                      : Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (venueAddress.isNotEmpty ||
                        googleMapsUrl.isNotEmpty ||
                        (venue.isNotEmpty &&
                            venue.toLowerCase() !=
                                eventName.toLowerCase())) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  if (venue.isNotEmpty &&
                                      venue.toLowerCase() !=
                                          eventName.toLowerCase()) ...[
                                    TextSpan(
                                      text: venue,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    if (venueAddress.isNotEmpty)
                                      TextSpan(
                                        text: '\n$venueAddress',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                  ] else if (venueAddress.isNotEmpty)
                                    TextSpan(
                                      text: venueAddress,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (googleMapsUrl.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _launchMapUrl(googleMapsUrl),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.map_outlined,
                                      size: 14,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // DATE & TIME - Highlighted prominently
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: isPrivate
                                  ? AppColors.purple  // Pure purple for invitations
                                  : Colors.blue.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatEventDateTimeLabel(
                                  dateStr: date,
                                  startTimeStr: e['start_time']?.toString(),
                                  endTimeStr: e['end_time']?.toString(),
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (clientName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      // Client name - Highlighted
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPrivate
                              ? const Color(0xFFF3E8FF)  // Soft purple for invitations
                              : const Color(0xFFEEF2FF),  // Light blue for available
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 14,
                              color: isPrivate
                                  ? AppColors.purple  // Purple for invitations
                                  : Colors.blue.shade600,  // Blue for available
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  children: [
                                    TextSpan(text: AppLocalizations.of(context)!.clientLabel),
                                    TextSpan(
                                      text: clientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (estimatedPay != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPrivate
                                      ? const Color(0xFFF3E8FF)  // Light purple for invitations
                                      : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  estimatedPay,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isPrivate
                                        ? AppColors.purple  // Purple for invitations
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        // Decorative triangle in bottom right corner
        Positioned(
          right: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(16),
            ),
            child: CustomPaint(
              size: const Size(40, 40),
              painter: _TrianglePainter(
                color: isPrivate
                    ? AppColors.purple.withOpacity(0.15)  // Purple for invitations
                    : Colors.blue.shade100.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RoleSummary {
  final String roleName;
  final int totalNeeded;
  final int eventCount;
  final List<Map<String, dynamic>> events;
  final int? remainingTotal;

  RoleSummary({
    required this.roleName,
    required this.totalNeeded,
    required this.eventCount,
    required this.events,
    this.remainingTotal,
  });
}

class _CalendarTab extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  final List<Map<String, dynamic>> availability;
  final double headerHeight;

  const _CalendarTab({
    required this.events,
    required this.userKey,
    required this.loading,
    required this.availability,
    this.headerHeight = 200.0,
  });

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  late final ValueNotifier<List<Map<String, dynamic>>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isAgendaView = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final accepted = _filterAccepted(widget.events, widget.userKey);
    return accepted.where((event) {
      final eventDate = _parseDate(event['date']?.toString());
      if (eventDate == null) return false;
      return isSameDay(eventDate, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Builder(
      builder: (context) {
        return Stack(
          children: [
        EnhancedRefreshIndicator(
          showLastRefreshTime: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // View toggle + Calendar or Agenda
              widget.loading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SliverToBoxAdapter(
                      child: Column(
                        children: [
                          SizedBox(height: widget.headerHeight), // AppBar + chips + banner
                          // View toggle row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceGray,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildViewToggleButton(
                                        icon: Icons.calendar_month_outlined,
                                        label: 'Month',
                                        isActive: !_isAgendaView,
                                        onTap: () => setState(() => _isAgendaView = false),
                                        theme: theme,
                                      ),
                                      _buildViewToggleButton(
                                        icon: Icons.view_agenda_outlined,
                                        label: 'Agenda',
                                        isActive: _isAgendaView,
                                        onTap: () => setState(() => _isAgendaView = true),
                                        theme: theme,
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Set Availability button (right-aligned)
                                GestureDetector(
                                  onTap: () => _showAvailabilityDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.navySpaceCadet.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.navySpaceCadet.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.event_available,
                                          size: 15,
                                          color: AppColors.navySpaceCadet.withValues(alpha: 0.7),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Set Availability',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.navySpaceCadet.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isAgendaView) ...[
                            Container(
                              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TableCalendar<Map<String, dynamic>>(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                calendarFormat: _calendarFormat,
                                eventLoader: _getEventsForDay,
                                startingDayOfWeek: StartingDayOfWeek.sunday,
                                availableGestures: AvailableGestures.horizontalSwipe,
                                daysOfWeekHeight: 30,
                                rowHeight: 46,
                                daysOfWeekStyle: DaysOfWeekStyle(
                                  weekdayStyle: TextStyle(
                                    color: AppColors.navySpaceCadet.withValues(alpha: 0.4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                  weekendStyle: TextStyle(
                                    color: AppColors.navySpaceCadet.withValues(alpha: 0.4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                  dowTextFormatter: (date, locale) =>
                                      ['SUN','MON','TUE','WED','THU','FRI','SAT'][date.weekday % 7],
                                ),
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, day, events) {
                                    final hasEvents = events.isNotEmpty;
                                    final availability = _getAvailabilityForDay(day);
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (hasEvents)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.only(right: 2),
                                            decoration: const BoxDecoration(
                                              color: AppColors.oceanBlue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (availability != null)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: availability['status'] == 'available'
                                                  ? AppColors.success
                                                  : AppColors.error,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                calendarStyle: CalendarStyle(
                                  outsideDaysVisible: false,
                                  cellMargin: const EdgeInsets.all(3),
                                  defaultTextStyle: const TextStyle(
                                    color: AppColors.navySpaceCadet,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  weekendTextStyle: const TextStyle(
                                    color: AppColors.navySpaceCadet,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  todayDecoration: const BoxDecoration(
                                    color: AppColors.primaryIndigo,
                                    shape: BoxShape.circle,
                                  ),
                                  todayTextStyle: const TextStyle(
                                    color: AppColors.navySpaceCadet,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  selectedDecoration: const BoxDecoration(
                                    color: AppColors.navySpaceCadet,
                                    shape: BoxShape.circle,
                                  ),
                                  selectedTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  titleTextStyle: const TextStyle(
                                    color: AppColors.navySpaceCadet,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                  headerPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  leftChevronMargin: const EdgeInsets.only(left: 8),
                                  rightChevronMargin: const EdgeInsets.only(right: 8),
                                  leftChevronPadding: EdgeInsets.zero,
                                  rightChevronPadding: EdgeInsets.zero,
                                  leftChevronIcon: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.navySpaceCadet.withValues(alpha: 0.07),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_left_rounded,
                                      color: AppColors.navySpaceCadet,
                                      size: 20,
                                    ),
                                  ),
                                  rightChevronIcon: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.navySpaceCadet.withValues(alpha: 0.07),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.navySpaceCadet,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                onDaySelected: _onDaySelected,
                                onFormatChanged: (format) {
                                  if (_calendarFormat != format) {
                                    setState(() => _calendarFormat = format);
                                  }
                                },
                                onPageChanged: (focusedDay) {
                                  _focusedDay = focusedDay;
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
              // Agenda view (replaces selected-day events & availability controls)
              if (_isAgendaView && !widget.loading)
                ..._buildAgendaSlivers(theme)
              else ...[
              // Events list
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _selectedEvents,
                builder: (context, value, _) {
                  final availability = _getAvailabilityForDay(_selectedDay!);

                  final children = <Widget>[
                    // Show availability status
                    if (availability != null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: availability['status'] == 'available'
                                ? [
                                    Colors.green.withOpacity(0.1),
                                    Colors.green.withOpacity(0.05),
                                  ]
                                : [
                                    Colors.red.withOpacity(0.1),
                                    Colors.red.withOpacity(0.05),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: availability['status'] == 'available'
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: availability['status'] == 'available'
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  availability['status'] == 'available'
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: availability['status'] == 'available'
                                      ? Colors.green
                                      : Colors.red,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      availability['status'] == 'available'
                                          ? 'Available'
                                          : 'Unavailable',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                availability['status'] ==
                                                    'available'
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${availability['startTime']} - ${availability['endTime']}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.7),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _deleteAvailability(availability['id']),
                                icon: const Icon(Icons.delete_outline),
                                color: theme.colorScheme.error,
                                tooltip: 'Delete availability',
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Empty state
                    if (value.isEmpty && availability == null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/calendar_empty.png',
                                width: 180,
                                height: 180,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No events or availability',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the clock icon to set your availability',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Events
                    ...value.map(
                      (event) => _buildEventCard(context, theme, event),
                    ),
                  ];

                  return SliverPadding(
                    padding: const EdgeInsets.all(8),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(children),
                    ),
                  );
                },
              ),
              ], // end else (calendar month view content)
              // Bottom padding for navigation bar
              SliverToBoxAdapter(
                child: Container(
                  height: 100, // Bottom padding for nav bar
                  color: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
          ],
        );
      },
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? AppColors.navySpaceCadet : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.navySpaceCadet : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAgendaSlivers(ThemeData theme) {
    final accepted = _filterAccepted(widget.events, widget.userKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Only show upcoming events (today and future)
    final upcoming = accepted.where((e) {
      final d = _parseDate(e['date']?.toString());
      return d != null && !d.isBefore(today);
    }).toList();

    // Sort by date
    upcoming.sort((a, b) {
      final da = _parseDate(a['date']?.toString()) ?? today;
      final db = _parseDate(b['date']?.toString()) ?? today;
      return da.compareTo(db);
    });

    // Group by date
    final grouped = <DateTime, List<Map<String, dynamic>>>{};
    for (final e in upcoming) {
      final d = _parseDate(e['date']?.toString());
      if (d != null) {
        grouped.putIfAbsent(d, () => []).add(e);
      }
    }

    final sortedDates = grouped.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 48, bottom: 32),
            child: Column(
              children: [
                Image.asset(
                  'assets/calendar_empty.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'No upcoming shifts',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accepted shifts will appear here',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final slivers = <Widget>[];
    for (final date in sortedDates) {
      final isToday = isSameDay(date, today);
      final dayLabel = isToday ? 'Today' : weekdays[date.weekday - 1];
      final dateLabel = '${months[date.month - 1]} ${date.day}';
      final events = grouped[date]!;
      final availability = _getAvailabilityForDay(date);

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.navySpaceCadet : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isToday ? AppColors.yellow : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isToday ? Colors.white : AppColors.navySpaceCadet,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                if (availability != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: availability['status'] == 'available' ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${events.length} shift${events.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildEventCard(context, theme, events[index]),
              childCount: events.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  Map<String, dynamic>? _getAvailabilityForDay(DateTime day) {
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    for (final availability in widget.availability) {
      if (availability['date'] == dateStr) {
        return availability;
      }
    }
    return null;
  }

  String _formatSelectedDate() {
    if (_selectedDay == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[_selectedDay!.month - 1]} ${_selectedDay!.day}';
  }

  Future<void> _showAvailabilityDialog(BuildContext context) async {
    if (_selectedDay == null) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AvailabilityDialog(selectedDay: _selectedDay!),
    );

    if (result != null) {
      final dateStr =
          '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}';
      final success = await AuthService.setAvailability(
        date: dateStr,
        startTime: result['startTime']!,
        endTime: result['endTime']!,
        status: result['status']!,
      );

      if (success) {
        // Refresh data through DataService
        context.read<DataService>().forceRefresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.availabilityUpdated)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToUpdateAvailability)),
        );
      }
    }
  }

  Future<void> _deleteAvailability(String id) async {
    final success = await AuthService.deleteAvailability(id: id);
    if (success) {
      // Refresh data through DataService
      context.read<DataService>().forceRefresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.availabilityDeleted)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.failedToDeleteAvailability)),
      );
    }
  }

  Widget _buildEventCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> event,
  ) {
    final eventName = event['event_name']?.toString() ?? 'Untitled Event';
    final clientName = event['client_name']?.toString() ?? '';
    final venue = event['venue_name']?.toString() ?? '';
    final start = event['start_time']?.toString();
    final end = event['end_time']?.toString();
    final date = event['date']?.toString();

    String timeLabel = '';
    if (date != null) {
      timeLabel = _formatEventDateTimeLabel(
        dateStr: date,
        startTimeStr: start,
        endTimeStr: end,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailPage(
                  event: event,
                  showRespondActions: false,
                  acceptedEvents: _filterAccepted(
                    widget.events,
                    widget.userKey,
                  ),
                  availability: widget.availability,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.oceanBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clientName.isNotEmpty ? clientName : eventName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navySpaceCadet,
                        ),
                      ),
                    ),
                  ],
                ),
                if (clientName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    eventName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.navySpaceCadet.withOpacity(0.7),
                    ),
                  ),
                ],
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    venue,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.navySpaceCadet.withOpacity(0.6),
                    ),
                  ),
                ],
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.oceanBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterAccepted(
    List<Map<String, dynamic>> events,
    String? userKey,
  ) {
    if (userKey == null) return const [];
    final List<Map<String, dynamic>> result = [];
    for (final e in events) {
      final acc = e['accepted_staff'];
      if (acc is List) {
        for (final a in acc) {
          if ((a is String && a == userKey) ||
              (a is Map && a['userKey'] == userKey)) {
            result.add(e);
            break;
          }
        }
      }
    }
    return result;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final iso = DateTime.tryParse(s);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    } catch (_) {}
    final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(s);
    if (m != null) {
      final y = int.tryParse(m.group(1) ?? '');
      final mo = int.tryParse(m.group(2) ?? '');
      final d = int.tryParse(m.group(3) ?? '');
      if (y != null && mo != null && d != null) return DateTime(y, mo, d);
    }
    return null;
  }
}

class _AvailabilityDialog extends StatefulWidget {
  final DateTime selectedDay;

  const _AvailabilityDialog({required this.selectedDay});

  @override
  State<_AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<_AvailabilityDialog> {
  String _status = 'available';
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr =
        '${months[widget.selectedDay.month - 1]} ${widget.selectedDay.day}, ${widget.selectedDay.year}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.event_available,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set Availability',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Status',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: theme.colorScheme.primaryContainer,
              ),
              segments: [
                ButtonSegment(
                  value: 'available',
                  label: Text(AppLocalizations.of(context)!.available),
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: _status == 'available'
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                ButtonSegment(
                  value: 'unavailable',
                  label: Text(AppLocalizations.of(context)!.unavailable),
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: _status == 'unavailable'
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (selection) {
                setState(() => _status = selection.first);
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Time Range',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) setState(() => _startTime = time);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _startTime.format(context),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.start,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                    size: 20,
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) setState(() => _endTime = time);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _endTime.format(context),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── AI Assistant hint ─────────────────────────────
            const SizedBox(height: 20),
            InkWell(
              onTap: () {
                final rootNav = Navigator.of(context, rootNavigator: true);
                Navigator.of(context).pop();
                if (SubscriptionService().isReadOnly) return;
                rootNav.push(
                  MaterialPageRoute(builder: (_) => const StaffAIChatScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/ai_assistant_logo.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Need a whole week off?',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '"Mark me unavailable May 10 – 18"',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
            // ─────────────────────────────────────────────────
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'status': _status,
              'startTime':
                  '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
              'endTime':
                  '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
            });
          },
          child: Text(AppLocalizations.of(context)!.save),
        ),
      ],
    );
  }
}
