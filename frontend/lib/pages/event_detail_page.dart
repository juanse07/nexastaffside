import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../auth_service.dart';
import '../utils/id.dart';

class EventDetailPage extends StatelessWidget {
  final Map<String, dynamic> event;
  final String? roleName;
  final bool showRespondActions;
  final List<Map<String, dynamic>> acceptedEvents;

  const EventDetailPage({
    super.key,
    required this.event,
    this.roleName,
    this.showRespondActions = true,
    this.acceptedEvents = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = event['venue_name']?.toString() ?? '';
    final venueAddress = event['venue_address']?.toString() ?? '';
    final lat = double.tryParse(event['venue_latitude']?.toString() ?? '');
    final lng = double.tryParse(event['venue_longitude']?.toString() ?? '');
    final hasCoords = lat != null && lng != null;

    final eventName = event['event_name']?.toString() ?? 'Untitled Event';
    final clientName = event['client_name']?.toString() ?? '';
    final headcount = event['headcount_total']?.toString() ?? '0';

    bool isRoleFull = false;
    if (roleName != null && roleName!.isNotEmpty) {
      final stats = event['role_stats'];
      if (stats is List) {
        for (final s in stats) {
          if (s is Map && (s['role']?.toString() ?? '') == roleName) {
            final remaining = int.tryParse(s['remaining']?.toString() ?? '');
            if (remaining != null && remaining <= 0) {
              isRoleFull = true;
            }
          }
        }
      }
    }

    final bool hasConflict = _hasTimeConflictWithAccepted(
      event,
      acceptedEvents,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Event Details',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasCoords) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(lat, lng),
                            initialZoom: 14,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              // Identify our app per OSM tile usage policy
                              userAgentPackageName: 'com.nexa.staffside',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(lat, lng),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (venue.isNotEmpty || venueAddress.isNotEmpty) ...[
                    Text(
                      venue.isNotEmpty ? venue : 'Venue',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (venueAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(venueAddress, style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 16),
                  ],
                  if (roleName != null && roleName!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Role: $roleName',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Card(
                    child: ListTile(
                      title: Text(eventName, style: theme.textTheme.titleLarge),
                      subtitle: clientName.isEmpty ? null : Text(clientName),
                      trailing: Text('Guests: $headcount'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showRespondActions)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _respond(context, theme, 'decline'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.onErrorContainer,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('DECLINE'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: (isRoleFull || hasConflict)
                            ? null
                            : () => _respond(context, theme, 'accept'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isRoleFull
                              ? 'FULL'
                              : (hasConflict ? 'CONFLICT' : 'ACCEPT'),
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

  Future<void> _respond(
    BuildContext context,
    ThemeData theme,
    String response,
  ) async {
    if (response == 'accept' &&
        _hasTimeConflictWithAccepted(event, acceptedEvents)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This event conflicts with another accepted event. Please resolve the conflict first.',
          ),
        ),
      );
      return;
    }
    final id = resolveEventId(event);
    if (id == null) return;
    final ok = await AuthService.respondToEvent(
      eventId: id,
      response: response,
      role: roleName?.trim().isEmpty == true ? null : roleName,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Event $response' : 'Failed to $response event'),
        backgroundColor: ok
            ? (response == 'accept' ? Colors.green : Colors.orange)
            : theme.colorScheme.error,
      ),
    );
    if (ok) Navigator.of(context).pop(true);
  }

  bool _hasTimeConflictWithAccepted(
    Map<String, dynamic> e,
    List<Map<String, dynamic>> accepted,
  ) {
    final d = _parseDate(e['date']?.toString());
    if (d == null) return false;
    final start = _parseTimeMinutes(e['start_time']?.toString());
    final end = _parseTimeMinutes(e['end_time']?.toString());
    if (start == null || end == null) return false;

    for (final a in accepted) {
      final ad = _parseDate(a['date']?.toString());
      if (ad == null) continue;
      if (ad.year != d.year || ad.month != d.month || ad.day != d.day) {
        continue;
      }
      final as = _parseTimeMinutes(a['start_time']?.toString());
      final ae = _parseTimeMinutes(a['end_time']?.toString());
      if (as == null || ae == null) continue;
      if (_overlaps(start, end, as, ae)) return true;
    }
    return false;
  }

  bool _overlaps(int s1, int e1, int s2, int e2) {
    final startMax = s1 > s2 ? s1 : s2;
    final endMin = e1 < e2 ? e1 : e2;
    return startMax < endMin;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final iso = DateTime.tryParse(s);
      if (iso != null) {
        return DateTime(iso.year, iso.month, iso.day);
      }
    } catch (_) {}
    final m = RegExp(r'^(\\d{4})[-/](\\d{1,2})[-/](\\d{1,2})$').firstMatch(s);
    if (m != null) {
      final y = int.tryParse(m.group(1) ?? '');
      final mo = int.tryParse(m.group(2) ?? '');
      final d = int.tryParse(m.group(3) ?? '');
      if (y != null && mo != null && d != null) {
        return DateTime(y, mo, d);
      }
    }
    return null;
  }

  int? _parseTimeMinutes(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final m = RegExp(
      r'^(\\d{1,2})(?::(\\d{2}))?\\s*([AaPp][Mm])?$',
    ).firstMatch(s);
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
}
