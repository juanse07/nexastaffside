import 'package:flutter/material.dart';

import 'event_detail_page.dart';

class RoleEventsPage extends StatelessWidget {
  final String roleName;
  final List<Map<String, dynamic>> events;
  final String? userKey;

  const RoleEventsPage({
    super.key,
    required this.roleName,
    required this.events,
    this.userKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Filter out events already accepted by the user
    final filtered = userKey == null
        ? events
        : events.where((e) {
            final accepted = e['accepted_staff'];
            if (accepted is List) {
              for (final a in accepted) {
                if (a is String && a == userKey) return false;
                if (a is Map && a['userKey'] == userKey) return false;
              }
            }
            return true;
          }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          roleName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final event = filtered[index];
          final title = event['event_name']?.toString() ?? 'Untitled Event';
          String? remainingLabel;
          int? remInt;
          int? capInt;
          final stats = event['role_stats'];
          if (stats is List) {
            for (final s in stats) {
              if (s is Map && (s['role']?.toString() ?? '') == roleName) {
                capInt = int.tryParse(s['capacity']?.toString() ?? '');
                remInt = int.tryParse(s['remaining']?.toString() ?? '');
              }
            }
          }
          if (remInt == null || capInt == null) {
            // Fallback compute from roles and accepted_staff
            final roles = event['roles'];
            if (roles is List) {
              for (final r in roles) {
                if (r is Map && (r['role']?.toString() ?? '') == roleName) {
                  capInt = int.tryParse(r['count']?.toString() ?? '');
                }
              }
            }
            int taken = 0;
            final accepted = event['accepted_staff'];
            if (accepted is List) {
              for (final a in accepted) {
                if (a is Map && (a['role']?.toString() ?? '') == roleName) {
                  taken += 1;
                }
              }
            }
            if (capInt != null) remInt = (capInt - taken).clamp(0, 1 << 30);
          }
          if (remInt != null && capInt != null) {
            remainingLabel = 'Remaining: $remInt / $capInt';
          }
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Text(
                remainingLabel ??
                    (event['venue_name']?.toString() ?? '').toString(),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        EventDetailPage(event: event, roleName: roleName),
                  ),
                );
              },
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}
