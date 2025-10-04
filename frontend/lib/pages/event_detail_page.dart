import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple_maps;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

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

  // Copied helpers from root to make this page self-sufficient
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

    try {
      final direct = Uri.parse(trimmed);
      if (direct.hasScheme) {
        candidates.add(direct);
      }
    } catch (_) {}

    final looksLikeHost = trimmed.startsWith('www.') ||
        trimmed.startsWith('maps.google.') ||
        trimmed.startsWith('google.') ||
        trimmed.startsWith('goo.gl/');
    if (!trimmed.contains('://') && looksLikeHost) {
      addUri('https://$trimmed');
    }

    final latLng = RegExp(r'^\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\s*$')
        .firstMatch(trimmed);
    if (latLng != null) {
      final lat = latLng.group(1);
      final lng = latLng.group(2);
      if (lat != null && lng != null) {
        addUri('geo:$lat,$lng?q=$lat,$lng');
        addUri('google.navigation:q=$lat,$lng');
        addUri('comgooglemaps://?q=$lat,$lng');
        addUri('comgooglemaps://?daddr=$lat,$lng');
        addUri('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        addUri('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      }
    } else {
      final q = Uri.encodeComponent(trimmed);
      addUri('geo:0,0?q=$q');
      addUri('google.navigation:q=$q');
      addUri('comgooglemaps://?q=$q');
      addUri('https://www.google.com/maps/search/?api=1&query=$q');
      addUri('https://www.google.com/maps/dir/?api=1&destination=$q');
    }

    return candidates;
  }

  Future<void> _launchMapUrl(String url) async {
    try {
      final candidates = _mapUriCandidates(url);
      for (final uri in candidates) {
        try {
          if (Platform.isAndroid) {
            final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (ok) return;
          } else {
            if (await canLaunchUrl(uri)) {
              final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (ok) return;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<geocoding.Location> _geocodeFirst(String address) async {
    final results = await geocoding.locationFromAddress(address);
    return results.first;
  }

  Widget _buildMapPreview(double lat, double lng) {
    if (Platform.isIOS) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 180,
          child: apple_maps.AppleMap(
            initialCameraPosition: apple_maps.CameraPosition(
              target: apple_maps.LatLng(lat, lng),
              zoom: 14,
            ),
            rotateGesturesEnabled: false,
            pitchGesturesEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            trafficEnabled: false,
            annotations: {
              apple_maps.Annotation(
                annotationId: apple_maps.AnnotationId('venue'),
                position: apple_maps.LatLng(lat, lng),
              ),
            },
          ),
        ),
      );
    }
    return ClipRRect(
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
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
      final ymd = RegExp(r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$')
          .firstMatch(input);
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
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
    final left = '${weekdayShort(date.weekday)} ${monthShort(date.month)} ${date.day}';
    String right = '';
    if (start != null && end != null) {
      right = '${formatTime(start.$1, start.$2)} — ${formatTime(end.$1, end.$2)} $tz';
    } else if (start != null) {
      right = '${formatTime(start.$1, start.$2)} $tz';
    }
    return right.isEmpty ? left : '$left • $right';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = event['venue_name']?.toString() ?? '';
    final venueAddress = event['venue_address']?.toString() ?? '';
    double? lat = double.tryParse(event['venue_latitude']?.toString() ?? '');
    double? lng = double.tryParse(event['venue_longitude']?.toString() ?? '');
    bool hasCoords = lat != null && lng != null;

    final eventName = event['event_name']?.toString() ?? 'Untitled Event';
    final clientName = event['client_name']?.toString() ?? '';
    final headcount = event['headcount_total']?.toString() ?? '0';
    final dateStr = event['date']?.toString();
    final startTimeStr = event['start_time']?.toString();
    final endTimeStr = event['end_time']?.toString();

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
      appBar: AppBar(title: Image.asset('assets/appbar_logo.png', height: 44)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time and duration card
                  Builder(builder: (context) {
                    final startMins = _parseTimeMinutes(startTimeStr);
                    final endMins = _parseTimeMinutes(endTimeStr);
                    String? durationLabel;
                    if (startMins != null && endMins != null && endMins > startMins) {
                      final mins = endMins - startMins;
                      final hours = (mins / 60).floor();
                      final rem = mins % 60;
                      durationLabel = rem == 0 ? '$hours hrs' : '$hours hrs ${rem}m';
                    }

                    final title = _formatEventDateTimeLabel(
                      dateStr: dateStr,
                      startTimeStr: startTimeStr,
                      endTimeStr: endTimeStr,
                    );

                    return Card(
                      color: theme.colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.schedule,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (durationLabel != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Approx. $durationLabel',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onPrimaryContainer.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  if (hasCoords) ...[
                    _buildMapPreview(lat!, lng!),
                    const SizedBox(height: 16),
                  ] else if (venueAddress.isNotEmpty) ...[
                    FutureBuilder<List<geocoding.Location>>(
                      future: geocoding.locationFromAddress(venueAddress),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final loc = snapshot.data!.first;
                          return Column(
                            children: [
                              _buildMapPreview(loc.latitude, loc.longitude),
                              const SizedBox(height: 16),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () {
                          final address = venueAddress.isNotEmpty ? venueAddress : venue;
                          if (address.isNotEmpty) {
                            _launchMapUrl(address);
                          }
                        },
                        icon: const Icon(Icons.directions, color: Colors.white),
                        label: const Text('Follow route in Maps'),
                      ),
                    ),
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
                                  Icons.work_outline,
                                  size: 16,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  roleName ?? 'Role',
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
                  const SizedBox(height: 16),
                  // Pay tariff section (if available)
                  Builder(builder: (context) {
                    final payInfo = event['pay_rate_info'];
                    if (payInfo == null) return const SizedBox.shrink();

                    String? payLabel;
                    if (payInfo is Map) {
                      // Try common patterns
                      final rate = payInfo['rate'] ?? payInfo['amount'] ?? payInfo['hourly'];
                      final currency = payInfo['currency'] ?? '\$';
                      final type = (payInfo['type'] ?? payInfo['basis'] ?? 'hour').toString();
                      if (rate != null) {
                        payLabel = '$currency$rate/${type.toLowerCase()}';
                      }
                    } else if (payInfo is String && payInfo.trim().isNotEmpty) {
                      payLabel = payInfo.trim();
                    }

                    if (payLabel == null) return const SizedBox.shrink();

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.attach_money),
                        title: const Text('Shift Pay'),
                        subtitle: Text(payLabel),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  // Uniform requirements
                  Builder(builder: (context) {
                    String uniform = (event['uniform']?.toString() ?? '').trim();
                    if (uniform.isEmpty) {
                      final role = (roleName ?? '').toLowerCase();
                      if (role.contains('banquet') || role.contains('server')) {
                        uniform = 'Dress pants and long sleeve shirt. Tie may be required.';
                      } else if (role.contains('bartend')) {
                        uniform = 'Black pants, long sleeve shirt. Tie may be required.';
                      } else if (role.contains('back') || role.contains('boh') || role.contains('kitchen')) {
                        uniform = 'Black pants and black t-shirt.';
                      } else {
                        uniform = 'Dress pants and long sleeve shirt.';
                      }
                    }

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.checkroom_outlined),
                        title: const Text('Uniform Requirements'),
                        subtitle: Text(uniform),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  // Parking instructions (if available)
                  Builder(builder: (context) {
                    final parking = (event['parking_instructions']?.toString() ?? '').trim();
                    if (parking.isEmpty) return const SizedBox.shrink();
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.local_parking_outlined),
                        title: const Text('Parking Instructions'),
                        subtitle: Text(parking),
                      ),
                    );
                  }),
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
