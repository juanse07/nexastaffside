import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../auth_service.dart';
import '../login_page.dart';
import '../utils/jwt.dart';
import '../widgets/event_card.dart';
import 'role_events_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  bool _checkingAuth = true;
  String? _userKey;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  Future<void> _ensureSignedIn() async {
    final token = await AuthService.getJwt();
    if (token == null && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
    final newToken = await AuthService.getJwt();
    _userKey = newToken == null ? null : decodeUserKeyFromJwt(newToken);
    if (mounted) {
      setState(() => _checkingAuth = false);
    }
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    final rawPrefix = (dotenv.env['API_PATH_PREFIX'] ?? '').trim();
    final prefix = rawPrefix.isEmpty
        ? ''
        : (rawPrefix.startsWith('/') ? rawPrefix : '/$rawPrefix');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await http.get(Uri.parse('$baseUrl$prefix/events'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as List<dynamic>;
        setState(() {
          _events = data.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() {
          _error = 'HTTP ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_checkingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Text(
            'Events',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: theme.colorScheme.surfaceTint,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Roles'),
              Tab(text: 'My Events'),
            ],
          ),
        ),
        body: Column(
          children: [
            _Header(
              loading: _loading,
              error: _error,
              totalEvents: _events.length,
              onRefresh: _loadEvents,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _RoleList(
                    summaries: _computeRoleSummaries(),
                    loading: _loading,
                  ),
                  _MyEventsList(
                    events: _events,
                    userKey: _userKey,
                    loading: _loading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RoleSummary> _computeRoleSummaries() {
    final Map<String, List<Map<String, dynamic>>> roleToEvents = {};
    final Map<String, int> roleToNeeded = {};
    // Exclude events the current user already accepted
    final Iterable<Map<String, dynamic>> sourceEvents = _events.where(
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
    if (mine.isEmpty && !loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No accepted events yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: mine.length,
      itemBuilder: (context, index) {
        final e = mine[index];
        final title = e['event_name']?.toString() ?? 'Untitled Event';
        final venue = e['venue_name']?.toString() ?? '';
        final address = e['venue_address']?.toString() ?? '';
        final city = e['city']?.toString() ?? '';
        final state = e['state']?.toString() ?? '';
        String? role;
        final acc = e['accepted_staff'];
        if (acc is List) {
          for (final a in acc) {
            if (a is Map && a['userKey'] == userKey) {
              role = a['role']?.toString();
              break;
            }
          }
        }
        final subtitleParts = <String>[];
        if (role != null && role.isNotEmpty) subtitleParts.add('Role: $role');
        final loc = [
          venue,
          address,
          [city, state].where((s) => s.isNotEmpty).join(', '),
        ].where((s) => s.toString().trim().isNotEmpty).join(' • ');
        if (loc.isNotEmpty) subtitleParts.add(loc);
        return Card(
          child: ListTile(
            title: Text(title),
            subtitle: subtitleParts.isEmpty
                ? null
                : Text(subtitleParts.join('  •  ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RoleEventsPage(roleName: role ?? 'My Role', events: [e]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final bool loading;
  final String? error;
  final int totalEvents;
  final Future<void> Function() onRefresh;

  const _Header({
    required this.loading,
    required this.error,
    required this.totalEvents,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage Your Events',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error != null ? error! : 'Found $totalEvents events',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: error != null
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(loading ? 'Loading...' : 'Refresh Events'),
          ),
        ],
      ),
    );
  }
}

class _RoleList extends StatelessWidget {
  final List<RoleSummary> summaries;
  final bool loading;

  const _RoleList({required this.summaries, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hide roles that are full (remainingTotal == 0) when backend provides role_stats
    final display = summaries
        .where((s) => s.remainingTotal == null || (s.remainingTotal ?? 0) > 0)
        .toList();
    if (display.isEmpty && !loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No roles found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap refresh to load events and roles from the database',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: display.length,
      itemBuilder: (context, index) {
        final s = display[index];
        final neededLabel = s.remainingTotal != null
            ? '${s.remainingTotal} remaining'
            : '${s.totalNeeded} needed';
        return EventCard(
          title: s.roleName,
          chips: [
            InfoChipData(
              icon: Icons.people_outline,
              label: neededLabel,
              colorKey: InfoChipColor.primary,
            ),
            InfoChipData(
              icon: Icons.event,
              label: '${s.eventCount} events',
              colorKey: InfoChipColor.secondary,
            ),
          ],
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RoleEventsPage(
                  roleName: s.roleName,
                  events: s.events,
                  userKey: (context.findAncestorStateOfType<_RootPageState>())
                      ?._userKey,
                ),
              ),
            );
          },
        );
      },
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
