import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../auth_service.dart';
import '../login_page.dart';
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
    return Scaffold(
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
            child: _RoleList(
              summaries: _computeRoleSummaries(),
              loading: _loading,
            ),
          ),
        ],
      ),
    );
  }

  List<RoleSummary> _computeRoleSummaries() {
    final Map<String, List<Map<String, dynamic>>> roleToEvents = {};
    final Map<String, int> roleToNeeded = {};
    for (final event in _events) {
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
      summaries.add(
        RoleSummary(
          roleName: role,
          totalNeeded: roleToNeeded[role] ?? 0,
          eventCount: evs.length,
          events: evs,
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
    if (summaries.isEmpty && !loading) {
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
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final s = summaries[index];
        return EventCard(
          title: s.roleName,
          chips: [
            InfoChipData(
              icon: Icons.people_outline,
              label: '${s.totalNeeded} needed',
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
                builder: (_) =>
                    RoleEventsPage(roleName: s.roleName, events: s.events),
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

  RoleSummary({
    required this.roleName,
    required this.totalNeeded,
    required this.eventCount,
    required this.events,
  });
}
