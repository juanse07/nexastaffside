import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth_service.dart';
import '../login_page.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';
import '../utils/id.dart';
import '../utils/jwt.dart';
import '../widgets/enhanced_refresh_indicator.dart';
import 'event_detail_page.dart';
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

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  Future<void> _ensureSignedIn() async {
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
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: theme.colorScheme.surfaceContainerLowest,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: SliverAppBar(
                      floating: true,
                      pinned: false,
                      snap: true,
                      expandedHeight: 100,
                      forceElevated: innerBoxIsScrolled,
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 16, bottom: 48),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/appbar_logo.png', height: 44),
                            if (dataService.isRefreshing) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      actions: [
                        const QuickRefreshButton(compact: true),
                        PopupMenuButton<_AccountMenuAction>(
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
                                    builder: (context) => const UserProfilePage(),
                                  ),
                                );
                                // Refresh avatar after returning from settings
                                await _loadUserProfile();
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
                                ? CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: NetworkImage(_userPictureUrl!),
                                  )
                                : const Icon(Icons.account_circle, size: 28),
                          ),
                        ),
                      ],
                      bottom: const TabBar(
                        tabs: [
                          Tab(text: 'Home'),
                          Tab(text: 'Roles'),
                          Tab(text: 'My Events'),
                          Tab(text: 'Calendar'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _HomeTab(
                    events: dataService.events,
                    userKey: _userKey,
                    loading: dataService.isLoading,
                  ),
                  _RoleList(
                    summaries: _computeRoleSummaries(dataService.events),
                    loading: dataService.isLoading,
                    allEvents: dataService.events,
                    userKey: _userKey,
                  ),
                  _MyEventsList(
                    events: dataService.events,
                    userKey: _userKey,
                    loading: dataService.isLoading,
                  ),
                  _CalendarTab(
                    events: dataService.events,
                    userKey: _userKey,
                    loading: dataService.isLoading,
                    availability: dataService.availability,
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
}

class _HomeTab extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  const _HomeTab({
    required this.events,
    required this.userKey,
    required this.loading,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic>? _upcoming;
  bool _loading = false;
  String? _status; // not_started | clocked_in | completed

  @override
  void initState() {
    super.initState();
    _computeUpcoming();
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
    });
    if (widget.userKey == null) return;
    // Filter accepted events for this user
    final List<Map<String, dynamic>> mine = [];
    for (final e in widget.events) {
      final accepted = e['accepted_staff'];
      if (accepted is List) {
        for (final a in accepted) {
          if (a is String && a == widget.userKey) {
            mine.add(e);
            break;
          }
          if (a is Map && a['userKey'] == widget.userKey) {
            mine.add(e);
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
      });
      return;
    }
    final next = bestFutureEvent;
    _upcoming = next;
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
    return EnhancedRefreshIndicator(
      child: CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
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
                    Color(0xFF7C3AED), // Deep purple
                    Color(0xFF6366F1), // Indigo
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Decorative circles
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
                                  'Welcome Back!',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _upcoming != null
                                      ? 'Your next shift is ready'
                                      : 'No upcoming shifts',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (widget.loading)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _upcoming != null
                                    ? Icons.event_available_rounded
                                    : Icons.calendar_today_rounded,
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
            if (venue.isNotEmpty ||
                venueAddress.isNotEmpty ||
                googleMapsUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (venue.isNotEmpty)
                          Text(
                            venue,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (venueAddress.isNotEmpty) ...[
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
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _launchMap(googleMapsUrl),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.map_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatEventDateTimeLabel(
                        dateStr: date,
                        startTimeStr: start,
                        endTimeStr: end,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClockActions(ThemeData theme) {
    return Column(
      children: [
        if (_status == null || _status == 'not_started')
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: !_loading ? _clockIn : null,
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
    for (final e in events) {
      final accepted = e['accepted_staff'];
      if (accepted is List) {
        for (final a in accepted) {
          if (a is String && a == userKey) {
            mine.add(e);
            break;
          }
          if (a is Map && a['userKey'] == userKey) {
            mine.add(e);
            break;
          }
        }
      }
    }
    return mine;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = _filterMyAccepted();

    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
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
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
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
                                'My Events',
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
                                    ? 'Loading events...'
                                    : mine.isEmpty
                                    ? 'No accepted events'
                                    : '${mine.length} ${mine.length == 1 ? 'event' : 'events'} accepted',
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
                                  Icons.event_available_rounded,
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
        if (mine.isEmpty && !loading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildEmptyState(theme),
            ),
          ),
        if (mine.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= mine.length) return null;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  index == 0 ? 0 : 8,
                  20,
                  index == mine.length - 1 ? 20 : 8,
                ),
                child: _buildEventCard(context, theme, mine[index]),
              );
            }, childCount: mine.length),
          ),
      ],
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
    if (roleNameOverride != null && roleNameOverride.trim().isNotEmpty) {
      role = roleNameOverride.trim();
    } else {
      final acc = e['accepted_staff'];
      if (acc is List) {
        for (final a in acc) {
          if (a is Map && a['userKey'] == userKey) {
            role = a['role']?.toString();
            break;
          }
        }
      }
    }

    return Container(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (clientName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    eventName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (role != null && role.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.work_outline,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          role,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (venue.isNotEmpty ||
                    venueAddress.isNotEmpty ||
                    googleMapsUrl.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (venue.isNotEmpty)
                              Text(
                                venue,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (venueAddress.isNotEmpty) ...[
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
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                            ),
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
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (date.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
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
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

    return EnhancedRefreshIndicator(
      child: CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
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
    if (roleNameOverride != null && roleNameOverride.trim().isNotEmpty) {
      role = roleNameOverride.trim();
    } else {
      final acc = e['accepted_staff'];
      if (acc is List) {
        for (final a in acc) {
          if (a is Map && a['userKey'] == userKey) {
            role = a['role']?.toString();
            break;
          }
        }
      }
    }

    return Container(
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
                  acceptedEvents: _acceptedEventsForUser(allEvents, userKey),
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
                  children: [
                    Container(
                      width: 8,
                      height: 8,
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (clientName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    eventName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (role != null && role.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.work_outline,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          role,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (venue.isNotEmpty ||
                    venueAddress.isNotEmpty ||
                    googleMapsUrl.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (venue.isNotEmpty)
                              Text(
                                venue,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (venueAddress.isNotEmpty) ...[
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
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                            ),
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
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (date.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
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
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
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
          child: CustomScrollView(
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
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
