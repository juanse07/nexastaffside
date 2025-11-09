import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

import 'event_detail_page.dart';

class RoleEventsPage extends StatelessWidget {
  final String roleName;
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final List<Map<String, dynamic>> availability;

  const RoleEventsPage({
    super.key,
    required this.roleName,
    required this.events,
    this.userKey,
    this.availability = const [],
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface.withOpacity(0.3),
              theme.colorScheme.surfaceContainerLowest,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final event = filtered[index];
            final eventName =
                event['event_name']?.toString() ?? 'Untitled Event';
            final clientName = event['client_name']?.toString() ?? '';
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
            if (timeLabel != null && timeLabel.isNotEmpty) {
              headerParts.add(timeLabel);
            }
            if (companyName.isNotEmpty) headerParts.add(companyName);
            final String? headerTitle = headerParts.isEmpty
                ? null
                : headerParts.join(' • ');

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.surface,
                        theme.colorScheme.surfaceContainerHigh.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      roleName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (clientName.isNotEmpty)
                          Text(
                            clientName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        if (clientName.isNotEmpty) const SizedBox(height: 4),
                        Text(
                          (remainingLabel?.isNotEmpty == true)
                              ? remainingLabel!
                              : (headerTitle ?? venueName),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final accepted = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => EventDetailPage(
                            event: event,
                            roleName: roleName,
                            availability: availability,
                          ),
                        ),
                      );
                      // If event was accepted/declined, pop back to root to show updated data
                      if (accepted == true && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
