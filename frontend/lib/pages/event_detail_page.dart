import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple_maps;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../services/data_service.dart';
import '../utils/id.dart';
import 'event_team_chat_page.dart';

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final String? roleName;
  final bool showRespondActions;
  final List<Map<String, dynamic>> acceptedEvents;
  final List<Map<String, dynamic>> availability;

  const EventDetailPage({
    super.key,
    required this.event,
    this.roleName,
    this.showRespondActions = true,
    this.acceptedEvents = const [],
    this.availability = const [],
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isResponding = false;

  // Convenience getters to access widget properties
  Map<String, dynamic> get event => widget.event;
  String? get roleName => widget.roleName;
  bool get showRespondActions => widget.showRespondActions;
  List<Map<String, dynamic>> get acceptedEvents => widget.acceptedEvents;
  List<Map<String, dynamic>> get availability => widget.availability;

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

    final eventStartDateTime =
        _resolveEventStartDateTime(dateStr, startTimeStr);
    final now = DateTime.now();
    final Duration? timeUntilStart = eventStartDateTime != null
        ? eventStartDateTime.difference(now)
        : null;
    final bool hasEventStarted =
        timeUntilStart != null && timeUntilStart.isNegative;
    final bool withinLockoutWindow = timeUntilStart != null &&
        !timeUntilStart.isNegative &&
        timeUntilStart < const Duration(hours: 72);
    final bool canRequestCancellation =
        !showRespondActions && timeUntilStart != null && !withinLockoutWindow && !hasEventStarted;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: !showRespondActions
            ? [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EventTeamChatPage(
                          eventId: (event['_id'] ?? event['id'] ?? '').toString(),
                          eventName: eventName,
                          chatEnabled: event['chatEnabled'] == true,
                        ),
                      ),
                    );
                  },
                  tooltip: 'Team Chat',
                ),
              ]
            : null,
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
                  if (clientName.isNotEmpty) ...[
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
                                  Icons.business,
                                  size: 16,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  clientName,
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
                      title: Text(
                        (roleName != null && roleName!.isNotEmpty) 
                            ? roleName! 
                            : eventName, 
                        style: theme.textTheme.titleLarge
                      ),
                      subtitle: Text(eventName),
                      trailing: Text('Guests: $headcount'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pay tariff section (if available)
                  Builder(builder: (context) {
                    // First check if there's tariff data in the role
                    Map<String, dynamic>? tariffData;
                    bool hasTariff = false;

                    if (roleName != null && roleName!.isNotEmpty) {
                      final roles = event['roles'];
                      if (roles is List) {
                        for (final r in roles) {
                          if (r is Map && (r['role']?.toString() ?? '') == roleName) {
                            final tariff = r['tariff'];
                            if (tariff is Map) {
                              tariffData = Map<String, dynamic>.from(tariff);
                              hasTariff = true;
                            }
                            break;
                          }
                        }
                      }
                    }

                    // Fall back to legacy pay_rate_info if no tariff found
                    if (!hasTariff) {
                      final payInfo = event['pay_rate_info'];
                      if (payInfo != null) {
                        String? payLabel;
                        if (payInfo is Map) {
                          final rate = payInfo['rate'] ?? payInfo['amount'] ?? payInfo['hourly'];
                          final currency = payInfo['currency'] ?? '\$';
                          final type = (payInfo['type'] ?? payInfo['basis'] ?? 'hour').toString();
                          if (rate != null) {
                            payLabel = '$currency$rate/${type.toLowerCase()}';
                          }
                        } else if (payInfo is String && payInfo.trim().isNotEmpty) {
                          payLabel = payInfo.trim();
                        }

                        if (payLabel != null) {
                          // Show legacy format as before
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
                        }
                      }
                    }

                    if (!hasTariff) return const SizedBox.shrink();

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _showTariffDetails(context, theme, tariffData!, roleName ?? '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.monetization_on_rounded,
                                  color: Colors.deepPurple,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shift Pay',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to view rate details',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.deepPurple.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.deepPurple,
                              ),
                            ],
                          ),
                        ),
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
                        onPressed: _isResponding
                            ? null
                            : () => _respond(context, theme, 'decline'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.onErrorContainer,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isResponding
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('DECLINE'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: (_isResponding || isRoleFull || hasConflict)
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
                        child: _isResponding
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                isRoleFull
                                    ? 'FULL'
                                    : (hasConflict ? 'CONFLICT' : 'ACCEPT'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton.icon(
                      onPressed: canRequestCancellation
                          ? () => _confirmCancellation(context, theme)
                          : null,
                      icon: const Icon(Icons.cancel_schedule_send_outlined, size: 18),
                      label: const Text('Request cancellation'),
                      style: ButtonStyle(
                        alignment: Alignment.centerLeft,
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                        foregroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.disabled)) {
                            return theme.colorScheme.onSurface.withOpacity(0.35);
                          }
                          if (states.contains(MaterialState.pressed)) {
                            return theme.colorScheme.onSurface.withOpacity(0.8);
                          }
                          return theme.colorScheme.onSurface.withOpacity(0.65);
                        }),
                        overlayColor: MaterialStateProperty.all(
                          theme.colorScheme.primary.withOpacity(0.05),
                        ),
                      ),
                    ),
                    if (!canRequestCancellation)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          hasEventStarted
                              ? 'This event has already started.'
                              : withinLockoutWindow
                                  ? 'Cancellation requests are unavailable within 72 hours of the start time.'
                                  : 'Cancellation unavailable. Please contact support.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  void _showTariffDetails(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> tariff,
    String role,
  ) {
    final rate = tariff['rate']?.toString() ?? 'N/A';
    final currency = tariff['currency']?.toString() ?? 'USD';
    final rateDisplay = tariff['rateDisplay']?.toString() ?? '$currency $rate/hr';

    // Calculate estimated pay based on event duration
    final startMins = _parseTimeMinutes(event['start_time']?.toString());
    final endMins = _parseTimeMinutes(event['end_time']?.toString());
    String? estimatedPay;

    if (startMins != null && endMins != null && endMins > startMins) {
      final hours = (endMins - startMins) / 60.0;
      final rateValue = double.tryParse(rate);
      if (rateValue != null) {
        final total = hours * rateValue;
        estimatedPay = '$currency ${total.toStringAsFixed(2)}';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Shift Pay - $role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  rateDisplay,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (estimatedPay != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Estimated Total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                estimatedPay,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Based on scheduled shift duration',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
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
    // Prevent duplicate submissions
    if (_isResponding) {
      debugPrint('⚠️ Response already in progress, ignoring duplicate click');
      return;
    }

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

    // Check for unavailability conflicts before accepting
    if (response == 'accept' && _hasAvailabilityConflict(event)) {
      final confirmed = await _showUnavailabilityWarningDialog(context, theme);
      if (confirmed != true) {
        // User canceled, don't proceed with acceptance
        return;
      }
      // User confirmed "Accept Anyway", continue with acceptance below
    }

    final id = resolveEventId(event);
    if (id == null) return;

    // Set loading state
    setState(() {
      _isResponding = true;
    });

    try {
      final result = await AuthService.respondToEvent(
        eventId: id,
        response: response,
        role: roleName?.trim().isEmpty == true ? null : roleName,
      );

      final success = result['success'] as bool;
      final errorMessage = result['message'] as String?;

      // Invalidate cache and force refresh to sync the event changes immediately
      if (success && mounted) {
        final dataService = context.read<DataService>();
        debugPrint('🎯 Event $response successful, invalidating cache and refreshing...');
        await dataService.invalidateEventsCache();
        // Force refresh to fetch updated events immediately
        await dataService.forceRefresh();
        debugPrint('🎯 Refresh complete after event $response');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Event ${response}ed'
                  : errorMessage ?? 'Failed to $response event',
            ),
            backgroundColor: success
                ? (response == 'accept' ? Colors.green : Colors.orange)
                : theme.colorScheme.error,
            duration: success ? const Duration(seconds: 2) : const Duration(seconds: 4),
          ),
        );
        if (success) Navigator.of(context).pop(true);
      }
    } finally {
      // Always clear loading state
      if (mounted) {
        setState(() {
          _isResponding = false;
        });
      }
    }
  }

  Future<void> _confirmCancellation(
    BuildContext context,
    ThemeData theme,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request cancellation?'),
        content: const Text(
          'We\'ll let the scheduling team know you can no longer make this event.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('KEEP EVENT'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: const Text('REQUEST CANCELLATION'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _respond(context, theme, 'decline');
    }
  }

  Future<bool?> _showUnavailabilityWarningDialog(
    BuildContext context,
    ThemeData theme,
  ) async {
    // Get conflict details for display
    final conflictingAvail = _getConflictingAvailability(event);

    // Format event date and time for display
    String formatEventTime() {
      final eventDate = _parseDate(event['date']?.toString());
      if (eventDate == null) return 'this event';

      final weekday = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][eventDate.weekday - 1];
      final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][eventDate.month - 1];
      final day = eventDate.day;

      final startTime = event['start_time']?.toString();
      final endTime = event['end_time']?.toString();

      String dateStr = '$weekday, $month $day';

      if (startTime != null && endTime != null && startTime.isNotEmpty && endTime.isNotEmpty) {
        return '$dateStr • $startTime — $endTime';
      }
      return dateStr;
    }

    // Format unavailability time for display
    String formatUnavailTime() {
      if (conflictingAvail == null) return 'All day';

      final startTime = conflictingAvail['startTime']?.toString();
      final endTime = conflictingAvail['endTime']?.toString();

      if (startTime != null && endTime != null && startTime.isNotEmpty && endTime.isNotEmpty) {
        return '$startTime — $endTime';
      }
      return 'All day';
    }

    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: const Text('Unavailability Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You have marked yourself as unavailable during this event:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Event:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 4),
                    child: Text(
                      formatEventTime(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.block,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Unavailable:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 4),
                    child: Text(
                      formatUnavailTime(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to accept this event?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: const Text('ACCEPT ANYWAY'),
          ),
        ],
      ),
    );
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

  DateTime? _resolveEventStartDateTime(
    String? dateStr,
    String? startTimeStr,
  ) {
    final date = _parseDate(dateStr);
    if (date == null) return null;
    final startMinutes = _parseTimeMinutes(startTimeStr);
    if (startMinutes == null) {
      return DateTime(date.year, date.month, date.day);
    }
    final hour = startMinutes ~/ 60;
    final minute = startMinutes % 60;
    return DateTime(date.year, date.month, date.day, hour, minute);
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

  // Check if an event conflicts with user's unavailability
  bool _hasAvailabilityConflict(Map<String, dynamic> event) {
    if (availability.isEmpty) return false;

    // Get event date (YYYY-MM-DD format)
    final eventDateStr = event['date']?.toString();
    if (eventDateStr == null || eventDateStr.isEmpty) return false;

    // Parse event date to ensure it's in YYYY-MM-DD format
    final eventDate = _parseDate(eventDateStr);
    if (eventDate == null) return false;
    final eventDateFormatted = '${eventDate.year.toString().padLeft(4, '0')}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';

    // Find unavailability records for this date
    final unavailableForDay = availability.where((avail) {
      return avail['date'] == eventDateFormatted &&
             avail['status'] == 'unavailable';
    }).toList();

    if (unavailableForDay.isEmpty) return false; // No unavailability = no conflict

    // Get event time range if it exists
    final eventStartTime = event['start_time']?.toString();
    final eventEndTime = event['end_time']?.toString();

    // If event doesn't have specific times, check for full-day unavailability
    if (eventStartTime == null || eventEndTime == null ||
        eventStartTime.isEmpty || eventEndTime.isEmpty) {
      // Event has no time specified, any unavailability on this day is a conflict
      return true;
    }

    // Check time overlap with each unavailability period
    for (final avail in unavailableForDay) {
      final availStart = avail['startTime']?.toString();
      final availEnd = avail['endTime']?.toString();

      if (availStart != null && availEnd != null &&
          availStart.isNotEmpty && availEnd.isNotEmpty) {
        if (_checkTimeOverlapWithAvailability(eventStartTime, eventEndTime, availStart, availEnd)) {
          return true; // Found a time conflict
        }
      }
    }

    return false; // No time conflicts found
  }

  // Check if two time ranges overlap (HH:mm format)
  bool _checkTimeOverlapWithAvailability(String start1, String end1, String start2, String end2) {
    try {
      // Convert HH:mm to minutes since midnight for easier comparison
      int timeToMinutes(String time) {
        final parts = time.split(':');
        if (parts.length != 2) return 0;
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        return hours * 60 + minutes;
      }

      final start1Min = timeToMinutes(start1);
      final end1Min = timeToMinutes(end1);
      final start2Min = timeToMinutes(start2);
      final end2Min = timeToMinutes(end2);

      // Check for overlap: ranges overlap if start1 < end2 AND start2 < end1
      return start1Min < end2Min && start2Min < end1Min;
    } catch (e) {
      debugPrint('Error checking time overlap: $e');
      return true; // On error, assume conflict to be safe
    }
  }

  // Get conflicting unavailability details for display in dialog
  Map<String, dynamic>? _getConflictingAvailability(Map<String, dynamic> event) {
    if (availability.isEmpty) return null;

    final eventDateStr = event['date']?.toString();
    if (eventDateStr == null || eventDateStr.isEmpty) return null;

    final eventDate = _parseDate(eventDateStr);
    if (eventDate == null) return null;
    final eventDateFormatted = '${eventDate.year.toString().padLeft(4, '0')}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';

    final unavailableForDay = availability.where((avail) {
      return avail['date'] == eventDateFormatted &&
             avail['status'] == 'unavailable';
    }).toList();

    if (unavailableForDay.isEmpty) return null;

    final eventStartTime = event['start_time']?.toString();
    final eventEndTime = event['end_time']?.toString();

    // If event has no specific times, return the first unavailability
    if (eventStartTime == null || eventEndTime == null ||
        eventStartTime.isEmpty || eventEndTime.isEmpty) {
      return unavailableForDay.first;
    }

    // Find the first conflicting time period
    for (final avail in unavailableForDay) {
      final availStart = avail['startTime']?.toString();
      final availEnd = avail['endTime']?.toString();

      if (availStart != null && availEnd != null &&
          availStart.isNotEmpty && availEnd.isNotEmpty) {
        if (_checkTimeOverlapWithAvailability(eventStartTime, eventEndTime, availStart, availEnd)) {
          return avail;
        }
      }
    }

    return null;
  }
}
