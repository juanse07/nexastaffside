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
          final eventName = event['event_name']?.toString() ?? 'Untitled Event';
          final venueName = event['venue_name']?.toString() ?? '';
          // Build time label from start/end times if present
          final startTime = event['start_time']?.toString().trim();
          final endTime = event['end_time']?.toString().trim();
          String? timeLabel;
          if ((startTime != null && startTime.isNotEmpty) ||
              (endTime != null && endTime.isNotEmpty)) {
            final start = (startTime == null || startTime.isEmpty)
                ? '—'
                : startTime;
            final end = (endTime == null || endTime.isEmpty) ? '—' : endTime;
            timeLabel = '$start - $end';
          }
          // Extract third-party company name if available
          String companyName = '';
          final thirdParty = event['third_party'];
          if (thirdParty is Map) {
            final comp = thirdParty['company_name'];
            if (comp != null) companyName = comp.toString();
          } else if (event['third_party_company_name'] != null) {
            companyName = event['third_party_company_name'].toString();
          }
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
          // Compose header: time and company shown prominently when present
          final List<String> headerParts = [];
          if (timeLabel != null && timeLabel.isNotEmpty)
            headerParts.add(timeLabel);
          if (companyName.isNotEmpty) headerParts.add(companyName);
          final String? headerTitle = headerParts.isEmpty
              ? null
              : headerParts.join(' • ');

          return Card(
            child: ListTile(
              title: Text(
                headerTitle ?? eventName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: headerTitle == null
                  ? Text(
                      (remainingLabel?.isNotEmpty == true)
                          ? remainingLabel!
                          : venueName,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          eventName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (remainingLabel?.isNotEmpty == true)
                              ? remainingLabel!
                              : venueName,
                        ),
                      ],
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
