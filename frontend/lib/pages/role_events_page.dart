import 'package:flutter/material.dart';

import 'event_detail_page.dart';

class RoleEventsPage extends StatelessWidget {
  final String roleName;
  final List<Map<String, dynamic>> events;

  const RoleEventsPage({
    super.key,
    required this.roleName,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final title = event['event_name']?.toString() ?? 'Untitled Event';
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Text(
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
