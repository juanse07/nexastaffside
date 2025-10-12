import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../auth_service.dart';
import '../login_page.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';
import '../utils/id.dart';
import '../utils/jwt.dart';
import '../widgets/enhanced_refresh_indicator.dart';
import 'event_detail_page.dart';
import 'past_events_page.dart';
import 'settings_page.dart';
import 'user_profile_page.dart';

enum _AccountMenuAction { profile, settings, logout }

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
  final latLng = RegExp(r'^\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\s*$')
      .firstMatch(trimmed);
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
            final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      '${weekdayShort(date.weekday)} ${monthShort(date.month)} ${date.day}';
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

class _RootPageState extends State<RootPage> {
  bool _checkingAuth = true;
  String? _userKey;
  String? _userPictureUrl;
  int _selectedBottomIndex = 0;
  Map<String, dynamic>? _upcoming;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  Future<void> _ensureSignedIn() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null && mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
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
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }

    // Load initial data using DataService
    if (mounted) {
      context.read<DataService>().loadInitialData();
    }

    // Load user profile (for avatar)
    unawaited(_loadUserProfile());
  }

  Future<void> _loadUserProfile() async {
    try {
      final me = await UserService.getMe();
      if (!mounted) return;
      setState(() {
        _userPictureUrl = (me.picture ?? '').trim().isEmpty ? null : me.picture!.trim();
      });
    } catch (_) {
      // Ignore errors loading profile for avatar
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (!mounted) return;

    // Clear cached data when signing out
    context.read<DataService>().clearCache();

    _userKey = null;
    _checkingAuth = true;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _computeUpcoming(List<Map<String, dynamic>> events) {
    if (_userKey == null) {
      _upcoming = null;
      return;
    }
    // Filter accepted events for this user
    final List<Map<String, dynamic>> mine = [];
    for (final e in events) {
      final accepted = e['accepted_staff'];
      if (accepted is List) {
        for (final a in accepted) {
          if (a is String && a == _userKey) {
            mine.add(e);
            break;
          }
          if (a is Map && a['userKey'] == _userKey) {
            mine.add(e);
            break;
          }
        }
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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

        return Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          body: IndexedStack(
            index: _selectedBottomIndex,
            children: [
              _HomeTab(
                events: dataService.events,
                userKey: _userKey,
                loading: dataService.isLoading,
                profileMenu: _buildProfileMenu(context),
                isRefreshing: dataService.isRefreshing,
                countdownText: _getSmartCountdownText(),
              ),
              _RolesSection(
                events: dataService.events,
                userKey: _userKey,
                loading: dataService.isLoading,
                availability: dataService.availability,
              ),
              _EarningsTab(
                events: dataService.events,
                userKey: _userKey,
                loading: dataService.isLoading,
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFFA855F7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'Home',
                      index: 0,
                    ),
                    _buildNavItem(
                      icon: Icons.work_outline_rounded,
                      selectedIcon: Icons.work_rounded,
                      label: 'Roles',
                      index: 1,
                    ),
                    _buildNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      selectedIcon: Icons.account_balance_wallet,
                      label: 'Earnings',
                      index: 2,
                    ),
                  ],
                ),
              ),
            ),
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
  }) {
    final isSelected = _selectedBottomIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedBottomIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 28,
                color: Colors.white,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
      (e) => !_isAcceptedByUser(e, _userKey),
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

  bool _isAcceptedByUser(Map<String, dynamic> event, String? userKey) {
    if (userKey == null) return false;
    final accepted = event['accepted_staff'];
    if (accepted is List) {
      for (final a in accepted) {
        if (a is String && a == userKey) return true;
        if (a is Map && a['userKey'] == userKey) return true;
      }
    }
    return false;
  }

  Widget _buildProfileMenu(BuildContext context) {
    return PopupMenuButton<_AccountMenuAction>(
      tooltip: 'Account',
      onSelected: (value) async {
        switch (value) {
          case _AccountMenuAction.profile:
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const UserProfilePage(),
              ),
            );
            await _loadUserProfile();
            break;
          case _AccountMenuAction.settings:
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsPage(),
              ),
            );
            setState(() {});
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
              Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('My Profile'),
            ],
          ),
        ),
        PopupMenuItem<_AccountMenuAction>(
          value: _AccountMenuAction.settings,
          child: Row(
            children: [
              Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Settings'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_AccountMenuAction>(
          value: _AccountMenuAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Logout'),
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
                  border: Border.all(
                    color: const Color(0xFF6B46C1),
                    width: 2,
                  ),
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
      width, height - 30,           // First control point - ease out from vertical
      width - 30, height,            // Second control point - ease into horizontal
      width - 60, height,            // End point - curved inward
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

class _HomeTab extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  final Widget profileMenu;
  final bool isRefreshing;
  final String countdownText;
  const _HomeTab({
    required this.events,
    required this.userKey,
    required this.loading,
    required this.profileMenu,
    required this.isRefreshing,
    required this.countdownText,
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
    super.dispose();
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
    setState(() {
      _upcoming = null;
      _status = null;
      _acceptedRole = null;
    });
    if (widget.userKey == null) return;
    // Filter accepted events for this user and extract the role
    final List<Map<String, dynamic>> mine = [];
    final Map<Map<String, dynamic>, String?> eventRoles = {};
    for (final e in widget.events) {
      final accepted = e['accepted_staff'];
      if (accepted is List) {
        for (final a in accepted) {
          if (a is String && a == widget.userKey) {
            mine.add(e);
            eventRoles[e] = null; // Legacy format without role
            break;
          }
          if (a is Map && a['userKey'] == widget.userKey) {
            mine.add(e);
            eventRoles[e] = a['role']?.toString(); // Extract role from Map
            break;
          }
        }
      }
    }
    if (mine.isEmpty) return;
    // Choose nearest upcoming (today/future and not already started). If none, show none.
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
    setState(() {
      _loading = false;
      _status = resp?['status']?.toString();
    });

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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
    setState(() {
      _loading = true;
    });
    final res = await AuthService.clockIn(eventId: id);
    setState(() {
      _loading = false;
      _status = res?['status']?.toString() ?? _status;
    });
  }

  Future<void> _clockOut() async {
    if (_upcoming == null) return;
    final id = resolveEventId(_upcoming!);
    if (id == null) return;
    setState(() {
      _loading = true;
    });
    final res = await AuthService.clockOut(eventId: id);
    setState(() {
      _loading = false;
      _status = res?['status']?.toString() ?? _status;
    });
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
      // Check 1: Date and time validation
      final eventDt = _eventDateTime(_upcoming!);
      if (eventDt == null) {
        setState(() {
          _canClockIn = false;
          _clockInError = 'Event date/time not available';
        });
        return;
      }

      final now = DateTime.now();
      // Allow clock-in 30 minutes before the event starts
      final earliestClockIn = eventDt.subtract(const Duration(minutes: 30));
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
            timeMessage = '$days day${days > 1 ? 's' : ''} and $hours hour${hours > 1 ? 's' : ''}';
          } else {
            timeMessage = '$days day${days > 1 ? 's' : ''}';
          }
        } else if (duration.inHours > 0) {
          final hours = duration.inHours;
          final minutes = duration.inMinutes % 60;
          if (minutes > 0) {
            timeMessage = '$hours hour${hours > 1 ? 's' : ''} and $minutes min${minutes > 1 ? 's' : ''}';
          } else {
            timeMessage = '$hours hour${hours > 1 ? 's' : ''}';
          }
        } else {
          final minutes = duration.inMinutes;
          timeMessage = '$minutes minute${minutes > 1 ? 's' : ''}';
        }

        setState(() {
          _canClockIn = false;
          _clockInError = 'Clock in available in $timeMessage';
        });
        return;
      }

      if (now.isAfter(latestClockIn)) {
        setState(() {
          _canClockIn = false;
          _clockInError = 'Event time has passed';
        });
        return;
      }

      // Check 2: Location validation
      final venueAddress = _upcoming!['venue_address']?.toString() ?? '';
      if (venueAddress.isEmpty) {
        // If no venue address, skip location check
        setState(() {
          _canClockIn = true;
          _clockInError = null;
        });
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _canClockIn = false;
            _clockInError = 'Location permission required';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _canClockIn = false;
          _clockInError = 'Location permission denied. Enable in settings.';
        });
        return;
      }

      // Get current location
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        setState(() {
          _canClockIn = false;
          _clockInError = 'Unable to get current location';
        });
        return;
      }

      // Get venue coordinates from address
      List<Location> locations;
      try {
        locations = await locationFromAddress(venueAddress);
      } catch (e) {
        // If geocoding fails, allow clock-in (venue address might be invalid)
        setState(() {
          _canClockIn = true;
          _clockInError = null;
        });
        return;
      }

      if (locations.isEmpty) {
        setState(() {
          _canClockIn = true;
          _clockInError = null;
        });
        return;
      }

      final venueLocation = locations.first;
      final distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        venueLocation.latitude,
        venueLocation.longitude,
      );

      // Allow clock-in within 500 meters (adjust as needed)
      const maxDistanceMeters = 500.0;
      if (distanceInMeters > maxDistanceMeters) {
        final distanceKm = (distanceInMeters / 1000).toStringAsFixed(1);
        setState(() {
          _canClockIn = false;
          _clockInError = 'Too far from venue (${distanceKm}km away)';
        });
        return;
      }

      // All checks passed!
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
    const double expandedHeight = 170.0;

    return EnhancedRefreshIndicator(
      showLastRefreshTime: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            expandedHeight: expandedHeight,
            automaticallyImplyLeading: false,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                // t = 1.0 when fully expanded, 0.0 when collapsed
                final double max = expandedHeight;
                final double min = kToolbarHeight + MediaQuery.of(context).padding.top;
                final double current = constraints.maxHeight.clamp(min, max);
                final double t = ((current - min) / (max - min)).clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Purple gradient background with custom clip
                    ClipPath(
                      clipper: AppBarClipper(),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF7A3AFB),
                              Color(0xFF5B27D8),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Decorative purple shapes layer
                    ClipPath(
                      clipper: AppBarClipper(),
                      child: Stack(
                        children: [
                          // Large light purple circle - top right
                          Positioned(
                            top: -40,
                            right: -20,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF9D7EF0).withOpacity(0.15),
                              ),
                            ),
                          ),
                          // Medium purple circle - top left
                          Positioned(
                            top: 20,
                            left: -30,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                              ),
                            ),
                          ),
                          // Small accent circle - bottom left
                          Positioned(
                            bottom: 10,
                            left: 30,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6D28D9).withOpacity(0.2),
                              ),
                            ),
                          ),
                          // Decorative blob - center right
                          Positioned(
                            top: 60,
                            right: 40,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFAA88FF).withOpacity(0.1),
                              ),
                            ),
                          ),
                          // Extra small accent - bottom right area
                          Positioned(
                            bottom: 30,
                            right: 80,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF9D7EF0).withOpacity(0.18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Top row: Profile menu (right)
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // Loading indicator (left side when refreshing)
                            if (widget.isRefreshing)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            const Spacer(),
                            widget.profileMenu,
                          ],
                        ),
                      ),
                    ),

                    // Big title & subtitle (fade out as we collapse)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Opacity(
                        opacity: t, // 1 expanded -> 0 collapsed
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome Back!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.countdownText,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_upcoming == null && !widget.loading) ...[
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Icons.event_available_outlined,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No upcoming events',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Accept an event from the Roles tab to see it here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
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
    final venue = e['event_name']?.toString() ?? e['venue_name']?.toString() ?? '';
    final venueAddress = e['venue_address']?.toString() ?? '';
    final rawMaps = e['google_maps_url']?.toString() ?? '';
    final googleMapsUrl = rawMaps.isNotEmpty
        ? rawMaps
        : (venueAddress.isNotEmpty ? venueAddress : venue);
    final date = e['date']?.toString() ?? '';
    final start = e['start_time']?.toString() ?? '';
    final end = e['end_time']?.toString() ?? '';
    final clientName = e['client_name']?.toString() ?? '';

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
              if (rateValue != null && startMins != null && endMins != null && endMins > startMins) {
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFAFAFC)],
        ),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.work_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _acceptedRole!,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
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
                    color: theme.colorScheme.onSurfaceVariant,
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
                      gradient: LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        clientName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                  color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Colors.white,
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
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
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
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (venue.isNotEmpty)
                            Text(
                              venue,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
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
                              color: Colors.white,
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
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.1),
                              theme.colorScheme.primary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              durationLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Duration',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFDCFCE7),
                              Color(0xFFF0FDF4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payments_rounded,
                              size: 20,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              estimatedPay,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Estimated',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green.shade700,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Estimate does not include applicable taxes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
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
              gradient: LinearGradient(
                colors: _canClockIn
                    ? const [Color(0xFF10B981), Color(0xFF059669)]
                    : [Colors.grey.shade400, Colors.grey.shade500],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _canClockIn
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
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
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
              label: Text(
                _loading ? 'Clocking in...' : 'Clock In',
                style: const TextStyle(
                  color: Colors.white,
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
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _clockInError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (_status == 'clocked_in')
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
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
    );
  }
}

// Roles section with nested tabs
class _RolesSection extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  final List<Map<String, dynamic>> availability;

  const _RolesSection({
    required this.events,
    required this.userKey,
    required this.loading,
    required this.availability,
  });

  @override
  State<_RolesSection> createState() => _RolesSectionState();
}

class _RolesSectionState extends State<_RolesSection> with SingleTickerProviderStateMixin {
  Set<String> _preferredRoles = {};
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    _loadPreferredRoles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_RolesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload preferences when widget is updated (e.g., after returning from settings)
    _loadPreferredRoles();
  }

  Future<void> _loadPreferredRoles() async {
    final roles = await UserService.getPreferredRoles();
    if (mounted) {
      setState(() {
        _preferredRoles = roles;
      });
    }
  }

  bool _isAcceptedByUser(Map<String, dynamic> event, String? userKey) {
    if (userKey == null) return false;
    final accepted = event['accepted_staff'];
    if (accepted is List) {
      for (final a in accepted) {
        if (a is String && a == userKey) return true;
        if (a is Map && a['userKey'] == userKey) return true;
      }
    }
    return false;
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
    final ymd = RegExp(r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$').firstMatch(input);
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
      if (_isAcceptedByUser(e, widget.userKey)) return false;
      // Filter out past events
      final dateStr = e['date']?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        final eventDate = _parseDateSafe(dateStr);
        if (eventDate != null && eventDate.isBefore(today)) {
          return false; // Exclude past events
        }
      }
      return true;
    });
    debugPrint('📋 Computing role summaries: ${widget.events.length} total events, ${sourceEvents.length} available (filtered out accepted and past)');
    for (final e in sourceEvents) {
      final stats = e['role_stats'];
      if (stats is List && stats.isNotEmpty) {
        for (final stat in stats) {
          if (stat is Map) {
            final role = stat['role']?.toString() ?? '';
            final remaining = int.tryParse(stat['remaining']?.toString() ?? '');
            if (role.isNotEmpty) {
              roleToEvents.putIfAbsent(role, () => []).add(e);
              roleToRemaining[role] = (roleToRemaining[role] ?? 0)! + (remaining ?? 0);
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
    final allSummaries = roleToEvents.entries.map((e) {
      return RoleSummary(
        roleName: e.key,
        totalNeeded: roleToNeeded[e.key] ?? 0,
        eventCount: e.value.length,
        events: e.value,
        remainingTotal: roleToRemaining[e.key],
      );
    }).toList()
      ..sort((a, b) => b.eventCount.compareTo(a.eventCount));

    // Filter by preferred roles if any are selected
    if (_preferredRoles.isEmpty) {
      debugPrint('🔍 No role preferences set, showing all ${allSummaries.length} roles');
      return allSummaries;
    } else {
      final filtered = allSummaries.where((s) => _preferredRoles.contains(s.roleName)).toList();
      debugPrint('🔍 Filtered to ${filtered.length} preferred roles (from ${allSummaries.length} total)');
      return filtered;
    }
  }

  List<Map<String, dynamic>> _getMyAcceptedEvents() {
    if (widget.userKey == null) return const [];
    final List<Map<String, dynamic>> mine = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final e in widget.events) {
      final accepted = e['accepted_staff'];
      if (accepted is List) {
        bool isAccepted = false;
        for (final a in accepted) {
          if (a is String && a == widget.userKey) {
            isAccepted = true;
            break;
          }
          if (a is Map && a['userKey'] == widget.userKey) {
            isAccepted = true;
            break;
          }
        }

        // Only include if accepted AND event is today or in the future
        if (isAccepted) {
          final eventDate = _parseDateSafe(e['date']?.toString() ?? '');
          if (eventDate != null && !eventDate.isBefore(today)) {
            mine.add(e);
          }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleSummaries = _computeRoleSummaries();
    final availableCount = roleSummaries.length;
    final totalPositions = roleSummaries.fold<int>(
      0,
      (sum, role) => sum + role.totalNeeded,
    );

    // Get My Events statistics
    final myEvents = _getMyAcceptedEvents();
    final myEventsCount = myEvents.length;
    final myEventsTotalHours = _calculateTotalHours(myEvents);

    // Dynamic title and subtitle based on current tab
    String appBarTitle;
    String appBarSubtitle;

    switch (_currentTabIndex) {
      case 0: // Available tab
        appBarTitle = 'Available Roles';
        appBarSubtitle = '$availableCount roles • $totalPositions positions open';
        break;
      case 1: // My Events tab
        appBarTitle = 'My Events';
        appBarSubtitle = widget.loading
            ? 'Loading events...'
            : myEventsCount == 0
                ? 'No accepted events'
                : '$myEventsCount ${myEventsCount == 1 ? 'event' : 'events'} • $myEventsTotalHours hrs accepted';
        break;
      case 2: // Calendar tab
        appBarTitle = 'Calendar';
        appBarSubtitle = 'View your scheduled events';
        break;
      default:
        appBarTitle = 'Available Roles';
        appBarSubtitle = '$availableCount roles • $totalPositions positions open';
    }

    return NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: false,
              floating: true,
              snap: true,
              expandedHeight: 120.0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Purple gradient background with custom clip
                    ClipPath(
                      clipper: AppBarClipper(),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF7A3AFB),
                              Color(0xFF5B27D8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Decorative purple shapes layer
                    ClipPath(
                      clipper: AppBarClipper(),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -40,
                            right: -20,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF9D7EF0).withOpacity(0.15),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 20,
                            left: -30,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Title and stats
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              appBarTitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appBarSubtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF6A1B9A),
                  unselectedLabelColor: const Color(0xFF6A1B9A).withOpacity(0.6),
                  indicatorColor: const Color(0xFF6A1B9A),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Available'),
                    Tab(text: 'My Events'),
                    Tab(text: 'Calendar'),
                  ],
                ),
                safeAreaPadding: MediaQuery.of(context).padding.top,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _RoleList(
              summaries: roleSummaries,
              loading: widget.loading,
              allEvents: widget.events,
              userKey: widget.userKey,
            ),
            _MyEventsList(
              events: widget.events,
              userKey: widget.userKey,
              loading: widget.loading,
            ),
            _CalendarTab(
              events: widget.events,
              userKey: widget.userKey,
              loading: widget.loading,
              availability: widget.availability,
            ),
          ],
        ),
    );
  }
}

// TabBar delegate for SliverPersistentHeader
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final double safeAreaPadding;

  _TabBarDelegate(this.tabBar, {this.safeAreaPadding = 0.0});

  @override
  double get minExtent => tabBar.preferredSize.height + safeAreaPadding;

  @override
  double get maxExtent => tabBar.preferredSize.height + safeAreaPadding;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: 4.0,
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      safeAreaPadding != oldDelegate.safeAreaPadding;
}

// Earnings tab with approved hours breakdown
class _EarningsTab extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;

  const _EarningsTab({
    required this.events,
    required this.userKey,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (userKey == null) {
      return Center(
        child: Text(
          'Please log in to view earnings',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<Map<String, dynamic>>(
                future: _calculateEarnings(events, userKey!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading earnings',
                        style: theme.textTheme.bodyLarge,
                      ),
                    );
                  }

                  final data = snapshot.data;
                  if (data == null || data['yearTotal'] == 0.0) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 80,
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Earnings Yet',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Complete events to see your earnings here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final yearTotal = data['yearTotal'] as double;
                  final monthlyData = data['monthlyData'] as List<Map<String, dynamic>>;
                  final currentYear = DateTime.now().year;

                  // Calculate current month earnings for header
                  final now = DateTime.now();
                  final currentMonthData = monthlyData.where((m) =>
                    m['monthNum'] == now.month
                  ).firstOrNull;
                  final currentMonthEarnings = currentMonthData?['totalEarnings'] as double? ?? 0.0;

                  return CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        pinned: false,
                        floating: true,
                        snap: true,
                        expandedHeight: 120.0,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Purple gradient background with custom clip
                              ClipPath(
                                clipper: AppBarClipper(),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF7A3AFB),
                                        Color(0xFF5B27D8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Decorative purple shapes layer
                              ClipPath(
                                clipper: AppBarClipper(),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: -40,
                                      right: -20,
                                      child: Container(
                                        width: 180,
                                        height: 180,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF9D7EF0).withOpacity(0.15),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 20,
                                      left: -30,
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Title and stats
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'My Earnings',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'This month: \$${currentMonthEarnings.toStringAsFixed(2)} • YTD: \$${yearTotal.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Year Total Card
                            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6B46C1), // Purple
                    Color(0xFF9333EA), // Lighter purple
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B46C1).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$currentYear Total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '\$${yearTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total approved earnings',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Monthly Breakdown Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 20,
                    color: Color(0xFF6B46C1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Monthly Breakdown',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Monthly Cards
            ...monthlyData.map((month) {
              final monthName = month['month'] as String;
              final monthNum = month['monthNum'] as int;
              final totalEarnings = month['totalEarnings'] as double;
              final totalHours = month['totalHours'] as double;
              final eventCount = month['eventCount'] as int;
              final avgRate = totalHours > 0 ? totalEarnings / totalHours : 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _MonthlyEarningsDetailPage(
                          monthName: monthName,
                          monthNum: monthNum,
                          year: currentYear,
                          events: events,
                          userKey: userKey!,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9333EA),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  monthName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  '\$${totalEarnings.toStringAsFixed(2)}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6B46C1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF6B46C1),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                icon: Icons.access_time,
                                label: 'Hours',
                                value: totalHours.toStringAsFixed(1),
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                icon: Icons.event,
                                label: 'Events',
                                value: '$eventCount',
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                icon: Icons.trending_up,
                                label: 'Avg Rate',
                                value: '\$${avgRate.toStringAsFixed(0)}/hr',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                        ),
                      );
                    }).toList(),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              );
  }

  Future<Map<String, dynamic>> _calculateEarnings(
    List<Map<String, dynamic>> events,
    String userKey,
  ) async {
    double yearTotal = 0.0;
    final Map<int, Map<String, dynamic>> monthlyMap = {};
    final currentYear = DateTime.now().year;

    for (final event in events) {
      final eventDate = _parseEventDate(event['date']);
      if (eventDate == null || eventDate.year != currentYear) continue;

      final acceptedStaff = event['accepted_staff'] as List?;
      if (acceptedStaff == null) continue;

      // Find this user's attendance
      for (final staff in acceptedStaff) {
        if (staff['userKey'] != userKey) continue;

        final attendance = staff['attendance'] as List?;
        if (attendance == null || attendance.isEmpty) continue;

        final staffRole = staff['role']?.toString() ?? '';

        // Find tariff rate for this role
        double hourlyRate = 0.0;
        final roles = event['roles'] as List?;
        if (roles != null) {
          for (final role in roles) {
            if (role['role']?.toString() == staffRole) {
              final tariff = role['tariff'];
              if (tariff != null && tariff['rate'] != null) {
                hourlyRate = (tariff['rate'] as num).toDouble();
              }
              break;
            }
          }
        }

        // Calculate earnings from approved hours
        for (final session in attendance) {
          final approvedHours = session['approvedHours'];
          final status = session['status']?.toString();

          if (approvedHours != null && status == 'approved') {
            final hours = (approvedHours as num).toDouble();
            final earnings = hours * hourlyRate;

            yearTotal += earnings;

            final month = eventDate.month;
            if (!monthlyMap.containsKey(month)) {
              monthlyMap[month] = {
                'month': _getMonthName(month),
                'totalEarnings': 0.0,
                'totalHours': 0.0,
                'eventCount': 0,
                'eventIds': <String>{},
              };
            }

            monthlyMap[month]!['totalEarnings'] =
                (monthlyMap[month]!['totalEarnings'] as double) + earnings;
            monthlyMap[month]!['totalHours'] =
                (monthlyMap[month]!['totalHours'] as double) + hours;

            final eventId = event['_id']?.toString() ?? event['id']?.toString() ?? '';
            if (eventId.isNotEmpty) {
              (monthlyMap[month]!['eventIds'] as Set<String>).add(eventId);
              monthlyMap[month]!['eventCount'] =
                  (monthlyMap[month]!['eventIds'] as Set<String>).length;
            }
          }
        }
      }
    }

    // Convert to sorted list
    final monthlyData = monthlyMap.entries
        .map((e) => {
              'monthNum': e.key,
              'month': e.value['month'],
              'totalEarnings': e.value['totalEarnings'],
              'totalHours': e.value['totalHours'],
              'eventCount': e.value['eventCount'],
            })
        .toList();

    monthlyData.sort((a, b) => (b['monthNum'] as int).compareTo(a['monthNum'] as int));

    return {
      'yearTotal': yearTotal,
      'monthlyData': monthlyData,
    };
  }

  DateTime? _parseEventDate(dynamic date) {
    if (date == null) return null;
    try {
      if (date is DateTime) return date;
      return DateTime.parse(date.toString());
    } catch (e) {
      return null;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _MonthlyEarningsDetailPage extends StatelessWidget {
  final String monthName;
  final int monthNum;
  final int year;
  final List<Map<String, dynamic>> events;
  final String userKey;

  const _MonthlyEarningsDetailPage({
    required this.monthName,
    required this.monthNum,
    required this.year,
    required this.events,
    required this.userKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthlyEvents = _getMonthlyEvents();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('$monthName $year'),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
      ),
      body: monthlyEvents.isEmpty
          ? Center(
              child: Text(
                'No events found for this month',
                style: theme.textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: monthlyEvents.length,
              itemBuilder: (context, index) {
                final eventData = monthlyEvents[index];
                return _buildEventCard(context, eventData);
              },
            ),
    );
  }

  List<Map<String, dynamic>> _getMonthlyEvents() {
    final List<Map<String, dynamic>> monthlyEvents = [];

    for (final event in events) {
      final eventDate = _parseEventDate(event['date']);
      if (eventDate == null ||
          eventDate.year != year ||
          eventDate.month != monthNum) continue;

      final acceptedStaff = event['accepted_staff'] as List?;
      if (acceptedStaff == null) continue;

      for (final staff in acceptedStaff) {
        if (staff['userKey'] != userKey) continue;

        final attendance = staff['attendance'] as List?;
        if (attendance == null || attendance.isEmpty) continue;

        final staffRole = staff['role']?.toString() ?? '';

        // Find tariff rate for this role
        double hourlyRate = 0.0;
        final roles = event['roles'] as List?;
        if (roles != null) {
          for (final role in roles) {
            if (role['role']?.toString() == staffRole) {
              final tariff = role['tariff'];
              if (tariff != null && tariff['rate'] != null) {
                hourlyRate = (tariff['rate'] as num).toDouble();
              }
              break;
            }
          }
        }

        double totalHours = 0.0;
        for (final session in attendance) {
          final approvedHours = session['approvedHours'];
          final status = session['status']?.toString();

          if (approvedHours != null && status == 'approved') {
            totalHours += (approvedHours as num).toDouble();
          }
        }

        if (totalHours > 0) {
          monthlyEvents.add({
            'event': event,
            'role': staffRole,
            'hours': totalHours,
            'rate': hourlyRate,
            'earnings': totalHours * hourlyRate,
            'date': eventDate,
          });
        }
      }
    }

    monthlyEvents.sort((a, b) =>
      (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return monthlyEvents;
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> eventData) {
    final theme = Theme.of(context);
    final event = eventData['event'] as Map<String, dynamic>;
    final role = eventData['role'] as String;
    final hours = eventData['hours'] as double;
    final rate = eventData['rate'] as double;
    final earnings = eventData['earnings'] as double;
    final date = eventData['date'] as DateTime;

    final eventName = event['event_name']?.toString() ?? 'Untitled Event';
    final clientName = event['client_name']?.toString() ?? 'Unknown Client';
    final venueName = event['venue_name']?.toString() ?? 'No venue';
    final venueAddress = event['venue_address']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Name & Earnings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.month}/${date.day}/${date.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B46C1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${earnings.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6B46C1),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Client
            _DetailRow(
              icon: Icons.business,
              label: 'Client',
              value: clientName,
            ),

            const SizedBox(height: 8),

            // Venue
            _DetailRow(
              icon: Icons.location_on,
              label: 'Venue',
              value: venueAddress != null && venueAddress.isNotEmpty
                  ? '$venueName\n$venueAddress'
                  : venueName,
            ),

            const SizedBox(height: 8),

            // Role
            _DetailRow(
              icon: Icons.badge,
              label: 'Role',
              value: role,
            ),

            const SizedBox(height: 16),

            // Stats Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _EventStat(
                    label: 'Hours',
                    value: hours.toStringAsFixed(1),
                    icon: Icons.access_time,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                  _EventStat(
                    label: 'Rate',
                    value: '\$${rate.toStringAsFixed(2)}/hr',
                    icon: Icons.attach_money,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseEventDate(dynamic date) {
    if (date == null) return null;
    try {
      if (date is DateTime) return date;
      return DateTime.parse(date.toString());
    } catch (e) {
      return null;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF6B46C1).withOpacity(0.7),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _EventStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: const Color(0xFF6B46C1),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _MyEventsList extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;

  const _MyEventsList({
    required this.events,
    required this.userKey,
    required this.loading,
  });

  List<Map<String, dynamic>> _filterMyAccepted() {
    if (userKey == null) return const [];
    final List<Map<String, dynamic>> mine = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final e in events) {
      final accepted = e['accepted_staff'];
      if (accepted is List) {
        bool isAccepted = false;
        for (final a in accepted) {
          if (a is String && a == userKey) {
            isAccepted = true;
            break;
          }
          if (a is Map && a['userKey'] == userKey) {
            isAccepted = true;
            break;
          }
        }

        // Only include if accepted AND event is today or in the future
        if (isAccepted) {
          final eventDate = _parseDateSafe(e['date']?.toString() ?? '');
          if (eventDate != null && !eventDate.isBefore(today)) {
            mine.add(e);
          }
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final event in events) {
      final dateStr = event['date']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;

      final eventDate = _parseDateSafe(dateStr);
      if (eventDate == null) continue;

      // Find the start of the week (Monday)
      final weekStart = eventDate.subtract(Duration(days: eventDate.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      // Create week label
      String weekLabel;
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final nextWeekStart = thisWeekStart.add(const Duration(days: 7));

      if (weekStart == thisWeekStart) {
        weekLabel = 'This Week';
      } else if (weekStart == nextWeekStart) {
        weekLabel = 'Next Week';
      } else {
        // Format as "Oct Mon 20 - Sun 26" for future weeks
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final month = months[(weekStart.month - 1).clamp(0, 11)];
        final startDay = days[(weekStart.weekday - 1).clamp(0, 6)];
        final endDay = days[(weekEnd.weekday - 1).clamp(0, 6)];
        weekLabel = '$month $startDay ${weekStart.day} - $endDay ${weekEnd.day}';
      }

      grouped.putIfAbsent(weekLabel, () => []);
      grouped[weekLabel]!.add(event);
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
    final ymd = RegExp(r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$').firstMatch(input);
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
      slivers: [
        if (mine.isEmpty && !loading)
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PastEventsPage(
                        events: events,
                        userKey: userKey,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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

    // Sort week labels to show upcoming weeks first
    final preferredOrder = ['This Week', 'Next Week'];
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      final aIndex = preferredOrder.indexOf(a);
      final bIndex = preferredOrder.indexOf(b);

      // Both are in preferred order list
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);

      // One is in preferred order, prioritize it (This Week or Next Week come first)
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;

      // Both are date-based week labels (e.g., "Jan 15-21")
      // Extract earliest date from events in each week to determine order
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

    for (final weekLabel in sortedKeys) {
      final weekEvents = grouped[weekLabel]!;
      final weekHours = _calculateTotalHours(weekEvents);

      // Add week header
      sections.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    weekLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${weekEvents.length} ${weekEvents.length == 1 ? 'event' : 'events'} • $weekHours hrs',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Add events for this week
      sections.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= weekEvents.length) return null;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  index == weekEvents.length - 1 ? 0 : 8,
                ),
                child: _buildEventCard(context, theme, weekEvents[index]),
              );
            },
            childCount: weekEvents.length,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No accepted events',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Accept events from the Roles tab to see them here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
    final venue = e['event_name']?.toString() ?? e['venue_name']?.toString() ?? '';
    final venueAddress = e['venue_address']?.toString() ?? '';
    final rawMaps = e['google_maps_url']?.toString() ?? '';
    final googleMapsUrl = rawMaps.isNotEmpty
        ? rawMaps
        : (venueAddress.isNotEmpty ? venueAddress : venue);
    final date = e['date']?.toString() ?? '';

    // Debug: Check My Events data
    print('🔥 MY EVENTS DEBUG 🔥 Event: ${e['event_name']}');
    print('🔥 MY EVENTS DEBUG 🔥 venue_address: "$venueAddress"');
    print('🔥 MY EVENTS DEBUG 🔥 google_maps_url: "$googleMapsUrl"');
    print('🔥 MY EVENTS DEBUG 🔥 venue_name: "${e['venue_name']}"');
    print('🔥 MY EVENTS DEBUG 🔥 All keys: ${e.keys.toList()}');

    String? role;
    bool isConfirmed = false;
    if (roleNameOverride != null && roleNameOverride.trim().isNotEmpty) {
      role = roleNameOverride.trim();
    } else {
      final acc = e['accepted_staff'];
      if (acc is List) {
        for (final a in acc) {
          if (a is Map && a['userKey'] == userKey) {
            role = a['role']?.toString();
            final response = a['response']?.toString();
            isConfirmed = response == 'accept';
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHigh.withOpacity(0.7),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
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
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: isConfirmed
                            ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (role != null && role.isNotEmpty)
                            ? role
                            : (clientName.isNotEmpty ? clientName : eventName),
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
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
                if (venueAddress.isNotEmpty || googleMapsUrl.isNotEmpty ||
                    (venue.isNotEmpty && venue.toLowerCase() != eventName.toLowerCase())) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (venue.isNotEmpty && venue.toLowerCase() != eventName.toLowerCase())
                              Text(
                                venue,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (venueAddress.isNotEmpty) ...[
                              if (venue.isNotEmpty && venue.toLowerCase() != eventName.toLowerCase())
                                const SizedBox(height: 2),
                              const SizedBox(height: 2),
                              Text(
                                venueAddress,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (googleMapsUrl.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatEventDateTimeLabel(
                            dateStr: date,
                            startTimeStr: e['start_time']?.toString(),
                            endTimeStr: e['end_time']?.toString(),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (clientName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Event for: $clientName',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
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
  bool shouldRepaint(_TrianglePainter oldDelegate) => oldDelegate.color != color;
}

class _RoleList extends StatelessWidget {
  final List<RoleSummary> summaries;
  final bool loading;
  final List<Map<String, dynamic>> allEvents;
  final String? userKey;

  const _RoleList({
    required this.summaries,
    required this.loading,
    required this.allEvents,
    required this.userKey,
  });

  List<Map<String, dynamic>> _acceptedEventsForUser(
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

    if (roleEventPairs.isEmpty && !loading) {
      return EnhancedRefreshIndicator(
        showLastRefreshTime: false,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.work_off_outlined,
                      size: 80,
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Available Roles',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'No roles match your preferences. Tap Settings to adjust your role preferences.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
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
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1), // Indigo
                    Color(0xFF8B5CF6), // Purple
                    Color(0xFFA855F7), // Light purple
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Decorative elements
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -40,
                      left: -40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Available Roles',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  loading
                                      ? 'Loading roles...'
                                      : display.isEmpty
                                      ? 'No roles available'
                                      : '${display.length} ${display.length == 1 ? 'role needs' : 'roles need'} staff',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.work_outline_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom-right compact updated label
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Builder(
                        builder: (context) {
                          final ds = context.watch<DataService>();
                          if (!ds.hasData) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Updated ${ds.getLastRefreshTime()}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (roleEventPairs.isEmpty && !loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildEmptyState(theme),
              ),
            ),
          if (roleEventPairs.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= roleEventPairs.length) return null;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    index == 0 ? 0 : 8,
                    20,
                    index == roleEventPairs.length - 1 ? 20 : 8,
                  ),
                  child: _buildEventCard(
                    context,
                    theme,
                    roleEventPairs[index]['event'] as Map<String, dynamic>,
                    roleNameOverride:
                        roleEventPairs[index]['roleName'] as String,
                  ),
                );
              }, childCount: roleEventPairs.length),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.work_outline,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No roles available',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pull to refresh and check for new events',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
    final venue = e['event_name']?.toString() ?? e['venue_name']?.toString() ?? '';
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
      final acc = e['accepted_staff'];
      if (acc is List) {
        for (final a in acc) {
          if (a is Map && a['userKey'] == userKey) {
            role = a['role']?.toString();
            isUserAccepted = true;
            break;
          }
        }
      }
    }

    // Show blue indicator for unconfirmed roles (when user hasn't accepted yet)
    final showBlueIndicator = !isUserAccepted;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHigh.withOpacity(0.7),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
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
                      acceptedEvents: _acceptedEventsForUser(allEvents, userKey),
                    ),
                  ),
                );
                // Data refresh is handled by EventDetailPage calling forceRefresh()
                // which triggers Consumer<DataService> to rebuild automatically
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                              colors: showBlueIndicator
                                  ? [Colors.blue.shade400, Colors.blue.shade600]
                                  : [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: showBlueIndicator
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (role != null && role.isNotEmpty)
                                ? role
                                : (clientName.isNotEmpty ? clientName : eventName),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Available',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                if (venueAddress.isNotEmpty || googleMapsUrl.isNotEmpty ||
                    (venue.isNotEmpty && venue.toLowerCase() != eventName.toLowerCase())) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (venue.isNotEmpty && venue.toLowerCase() != eventName.toLowerCase())
                              Text(
                                venue,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (venueAddress.isNotEmpty) ...[
                              if (venue.isNotEmpty && venue.toLowerCase() != eventName.toLowerCase())
                                const SizedBox(height: 2),
                              const SizedBox(height: 2),
                              Text(
                                venueAddress,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (googleMapsUrl.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatEventDateTimeLabel(
                            dateStr: date,
                            startTimeStr: e['start_time']?.toString(),
                            endTimeStr: e['end_time']?.toString(),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (clientName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Event for: $clientName',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
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
                color: Colors.blue.shade100.withOpacity(0.6),
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

  const _CalendarTab({
    required this.events,
    required this.userKey,
    required this.loading,
    required this.availability,
  });

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  late final ValueNotifier<List<Map<String, dynamic>>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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
    return EnhancedRefreshIndicator(
      showLastRefreshTime: false,
      child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF8B5CF6), // Purple
                        Color(0xFFA855F7), // Light purple
                        Color(0xFFEC4899), // Pink
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Decorative elements
                        Positioned(
                          top: -30,
                          right: -30,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -40,
                          left: -40,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Calendar',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'View your events',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Calendar widget
              widget.loading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SliverToBoxAdapter(
                      child: Column(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: Container(
                              color: theme.colorScheme.surface,
                              child: TableCalendar<Map<String, dynamic>>(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                calendarFormat: _calendarFormat,
                                eventLoader: _getEventsForDay,
                                startingDayOfWeek: StartingDayOfWeek.sunday,
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, day, events) {
                                    final hasEvents = events.isNotEmpty;
                                    final availability =
                                        _getAvailabilityForDay(day);

                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (hasEvents)
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin:
                                                const EdgeInsets.only(right: 2),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF8B5CF6),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (availability != null)
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: availability['status'] ==
                                                      'available'
                                                  ? Colors.green
                                                  : Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                calendarStyle: CalendarStyle(
                                  outsideDaysVisible: false,
                                  weekendTextStyle: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  holidayTextStyle: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                  selectedDecoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFFEC4899),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  todayDecoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: true,
                                  titleCentered: true,
                                  formatButtonShowsNext: false,
                                  formatButtonDecoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  formatButtonTextStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                  leftChevronIcon: Icon(
                                    Icons.chevron_left,
                                    color: theme.colorScheme.primary,
                                  ),
                                  rightChevronIcon: Icon(
                                    Icons.chevron_right,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                selectedDayPredicate: (day) {
                                  return isSameDay(_selectedDay, day);
                                },
                                onDaySelected: _onDaySelected,
                                onFormatChanged: (format) {
                                  if (_calendarFormat != format) {
                                    setState(() {
                                      _calendarFormat = format;
                                    });
                                  }
                                },
                                onPageChanged: (focusedDay) {
                                  _focusedDay = focusedDay;
                                },
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
              // Availability controls
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.surfaceContainer,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Availability for ${_formatSelectedDate()}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showAvailabilityDialog(context),
                        icon: const Icon(Icons.access_time),
                        tooltip: 'Set availability',
                      ),
                    ],
                  ),
                  ),
                ),
              ),
              // Events list
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _selectedEvents,
                builder: (context, value, _) {
                  final availability = _getAvailabilityForDay(_selectedDay!);

                  final children = <Widget>[
                                          // Show availability status
                                          if (availability != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: availability['status'] ==
                                                        'available'
                                                    ? Colors.green
                                                        .withOpacity(0.1)
                                                    : Colors.red
                                                        .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      availability['status'] ==
                                                              'available'
                                                          ? Colors.green
                                                          : Colors.red,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    availability['status'] ==
                                                            'available'
                                                        ? Icons.check_circle
                                                        : Icons.cancel,
                                                    color:
                                                        availability['status'] ==
                                                                'available'
                                                            ? Colors.green
                                                            : Colors.red,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${availability['status'] == 'available' ? 'Available' : 'Unavailable'}: ${availability['startTime']} - ${availability['endTime']}',
                                                      style:
                                                          theme.textTheme.bodySmall,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () =>
                                                        _deleteAvailability(
                                                          availability['id'],
                                                        ),
                                                    icon:
                                                        const Icon(Icons.delete),
                                                    iconSize: 16,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          // Empty state
                                          if (value.isEmpty &&
                                              availability == null)
                                            Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(32),
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      width: 64,
                                                      height: 64,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            const LinearGradient(
                                                          colors: [
                                                            Color(0xFF8B5CF6),
                                                            Color(0xFFEC4899),
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                          32,
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.event_busy,
                                                        color: Colors.white,
                                                        size: 32,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'No events or availability',
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Tap the clock icon to set your availability',
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          // Events
                                          ...value.map(
                                            (event) => _buildEventCard(
                                              context,
                                              theme,
                                              event,
                                            ),
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
            ],
          ),
        );
      },
    );
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
        ).showSnackBar(const SnackBar(content: Text('Availability updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update availability')),
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
      ).showSnackBar(const SnackBar(content: Text('Availability deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete availability')),
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
                        gradient: LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clientName.isNotEmpty ? clientName : eventName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
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
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    venue,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
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
      title: Text('Set Availability for $dateStr'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'available',
                  label: Text('Available'),
                  icon: Icon(Icons.check_circle, color: Colors.green),
                ),
                ButtonSegment(
                  value: 'unavailable',
                  label: Text('Unavailable'),
                  icon: Icon(Icons.cancel, color: Colors.red),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (selection) {
                setState(() => _status = selection.first);
              },
            ),
            const SizedBox(height: 16),
            Text('Time Range', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
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
                    child: Text(_startTime.format(context)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to'),
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
                    child: Text(_endTime.format(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
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
          child: const Text('Save'),
        ),
      ],
    );
  }
}
