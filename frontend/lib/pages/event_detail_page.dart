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
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';
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

  /// Modern immersive map section with floating venue card
  Widget _buildModernMapSection({
    required double lat,
    required double lng,
    required String venueName,
    required String venueAddress,
    required ThemeData theme,
    required AppLocalizations l10n,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 260,
          child: Stack(
            children: [
              // Map layer
              Positioned.fill(
                child: _buildMapLayer(lat, lng),
              ),
              // Gradient overlay at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 140,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Custom animated marker
              Positioned(
                top: 75,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildModernMarker(),
                ),
              ),
              // Floating venue info card
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Venue icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.tealDark, AppColors.tealMedium],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Venue info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  venueName.isNotEmpty ? venueName : l10n.venue,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (venueAddress.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    venueAddress,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Directions button
                          GestureDetector(
                            onTap: () {
                              final address = venueAddress.isNotEmpty ? venueAddress : venueName;
                              if (address.isNotEmpty) {
                                _launchMapUrl(address);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.tealDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.directions_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Go',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modern floating marker with pulse effect
  Widget _buildModernMarker() {
    return SizedBox(
      width: 60,
      height: 70,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Shadow
          Positioned(
            bottom: 0,
            child: Container(
              width: 20,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Pin
          Container(
            width: 44,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.tealDark, AppColors.tealMedium],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.tealDark.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(height: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Raw map layer widget
  Widget _buildMapLayer(double lat, double lng) {
    if (Platform.isIOS) {
      return apple_maps.AppleMap(
        initialCameraPosition: apple_maps.CameraPosition(
          target: apple_maps.LatLng(lat, lng),
          zoom: 15,
        ),
        rotateGesturesEnabled: false,
        pitchGesturesEnabled: false,
        scrollGesturesEnabled: false,
        zoomGesturesEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        trafficEnabled: false,
        // No annotations - we use custom marker overlay
      );
    }
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(lat, lng),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.nexa.staffside',
        ),
        // No markers - we use custom marker overlay
      ],
    );
  }

  /// Fallback venue card when map can't be loaded
  Widget _buildVenueCardFallback({
    required String venueName,
    required String venueAddress,
    required ThemeData theme,
    required AppLocalizations l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.tealDark, AppColors.tealMedium],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueName.isNotEmpty ? venueName : l10n.venue,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (venueAddress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    venueAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final address = venueAddress.isNotEmpty ? venueAddress : venueName;
              if (address.isNotEmpty) {
                _launchMapUrl(address);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tealDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Go',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  // Legacy method kept for backwards compatibility
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
    required AppLocalizations l10n,
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
      final names = [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];
      return '${names[(weekday - 1).clamp(0, 6)]}.';
    }

    String monthShort(int month) {
      final names = [
        l10n.jan, l10n.feb, l10n.mar, l10n.apr, l10n.may, l10n.jun,
        l10n.jul, l10n.aug, l10n.sep, l10n.oct, l10n.nov, l10n.dec,
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
    final l10n = AppLocalizations.of(context)!;
    final venue = event['venue_name']?.toString() ?? '';
    final venueAddress = event['venue_address']?.toString() ?? '';
    double? lat = double.tryParse(event['venue_latitude']?.toString() ?? '');
    double? lng = double.tryParse(event['venue_longitude']?.toString() ?? '');
    bool hasCoords = lat != null && lng != null;

    final eventName = event['event_name']?.toString() ?? roleName ?? l10n.untitledEvent;
    final clientName = event['client_name']?.toString() ?? '';
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
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.85),
                    Colors.white.withValues(alpha: 0.7),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.textDark,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      // Title section
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              eventName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (clientName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                clientName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Chat button (only for accepted events)
                      if (!showRespondActions)
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.tealDark, AppColors.tealMedium],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
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
                          tooltip: l10n.teamChat,
                        )
                      else
                        const SizedBox(width: 48), // Balance the layout
                    ],
                  ),
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
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + kToolbarHeight + 12, 20, 20),
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
                      l10n: l10n,
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
                  // Modern immersive map section
                  if (hasCoords) ...[
                    _buildModernMapSection(
                      lat: lat!,
                      lng: lng!,
                      venueName: venue,
                      venueAddress: venueAddress,
                      theme: theme,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                  ] else if (venueAddress.isNotEmpty) ...[
                    FutureBuilder<List<geocoding.Location>>(
                      future: geocoding.locationFromAddress(venueAddress),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            height: 260,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Loading map...'),
                                ],
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final loc = snapshot.data!.first;
                          return Column(
                            children: [
                              _buildModernMapSection(
                                lat: loc.latitude,
                                lng: loc.longitude,
                                venueName: venue,
                                venueAddress: venueAddress,
                                theme: theme,
                                l10n: l10n,
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }
                        // Fallback: show venue card without map
                        return _buildVenueCardFallback(
                          venueName: venue,
                          venueAddress: venueAddress,
                          theme: theme,
                          l10n: l10n,
                        );
                      },
                    ),
                  ] else if (venue.isNotEmpty) ...[
                    // No address but have venue name - show simple card
                    _buildVenueCardFallback(
                      venueName: venue,
                      venueAddress: venueAddress,
                      theme: theme,
                      l10n: l10n,
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
                  // Event & Role info card with estimated pay
                  Builder(builder: (context) {
                    // Calculate shift duration in hours - try multiple field names
                    final startMins = _parseTimeMinutes(startTimeStr)
                        ?? _parseTimeMinutes(event['startTime']?.toString())
                        ?? _parseTimeMinutes(event['shift_start']?.toString());
                    final endMins = _parseTimeMinutes(endTimeStr)
                        ?? _parseTimeMinutes(event['endTime']?.toString())
                        ?? _parseTimeMinutes(event['shift_end']?.toString());

                    double? shiftHours;
                    if (startMins != null && endMins != null) {
                      // Handle overnight shifts (end < start means next day)
                      int duration = endMins - startMins;
                      if (duration <= 0) {
                        duration += 24 * 60; // Add 24 hours for overnight
                      }
                      shiftHours = duration / 60.0;
                    }

                    // Also try to get duration directly from event data
                    if (shiftHours == null) {
                      final durationHrs = double.tryParse(event['duration_hours']?.toString() ?? '');
                      final durationMins = double.tryParse(event['duration_minutes']?.toString() ?? '');
                      if (durationHrs != null) {
                        shiftHours = durationHrs + (durationMins ?? 0) / 60.0;
                      }
                    }

                    // Get tariff data for rate calculation
                    Map<String, dynamic>? tariffData;
                    double? hourlyRate;
                    String? totalPayDisplay;

                    if (roleName != null && roleName!.isNotEmpty) {
                      final roles = event['roles'];
                      if (roles is List) {
                        for (final r in roles) {
                          if (r is Map && (r['role']?.toString() ?? '') == roleName) {
                            final tariff = r['tariff'];
                            if (tariff is Map) {
                              tariffData = Map<String, dynamic>.from(tariff);
                              hourlyRate = double.tryParse(tariff['hourlyRate']?.toString() ?? '');
                            }
                            break;
                          }
                        }
                      }
                    }

                    // Fall back to legacy pay_rate_info
                    if (hourlyRate == null) {
                      final payInfo = event['pay_rate_info'];
                      if (payInfo is Map) {
                        hourlyRate = double.tryParse(
                          (payInfo['rate'] ?? payInfo['amount'] ?? payInfo['hourly'] ?? payInfo['hourlyRate'])?.toString() ?? ''
                        );
                      } else if (payInfo is num) {
                        hourlyRate = payInfo.toDouble();
                      }
                    }

                    // Try direct event fields for hourly rate
                    if (hourlyRate == null) {
                      hourlyRate = double.tryParse(event['hourlyRate']?.toString() ?? '')
                          ?? double.tryParse(event['hourly_rate']?.toString() ?? '')
                          ?? double.tryParse(event['rate']?.toString() ?? '')
                          ?? double.tryParse(event['payRate']?.toString() ?? '');
                    }

                    // Calculate total pay
                    if (hourlyRate != null && shiftHours != null) {
                      final totalPay = hourlyRate * shiftHours;
                      totalPayDisplay = '\$${totalPay.toStringAsFixed(2)}';
                    } else if (hourlyRate != null) {
                      totalPayDisplay = '\$${hourlyRate.toStringAsFixed(2)}/hr';
                    }

                    // Debug: print what we found
                    debugPrint('[EventDetail] startMins=$startMins, endMins=$endMins, shiftHours=$shiftHours, hourlyRate=$hourlyRate');
                    debugPrint('[EventDetail] event keys: ${event.keys.toList()}');

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      color: theme.colorScheme.surface,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: tariffData != null
                            ? () => _showTariffDetails(context, theme, tariffData!, roleName ?? '', l10n)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Role name
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.tealDark, AppColors.tealMedium],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.work_outline_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (roleName != null && roleName!.isNotEmpty)
                                              ? roleName!
                                              : 'Your Role',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          eventName,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Payment section - show both hourly and total
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.success.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Hourly rate row
                                    if (hourlyRate != null) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule_outlined,
                                                size: 18,
                                                color: AppColors.textTertiary,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Hourly Rate',
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: AppColors.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '\$${hourlyRate.toStringAsFixed(2)}/hr',
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        height: 1,
                                        color: AppColors.success.withValues(alpha: 0.15),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    // Total payment row (prominent)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.payments_outlined,
                                                size: 18,
                                                color: AppColors.success,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              shiftHours != null ? 'Total Payment' : 'Estimated Pay',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          (hourlyRate != null && shiftHours != null)
                                              ? '\$${(hourlyRate * shiftHours).toStringAsFixed(2)}'
                                              : (hourlyRate != null ? '\$${hourlyRate.toStringAsFixed(2)}/hr' : '--'),
                                          style: theme.textTheme.headlineSmall?.copyWith(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Duration info if available
                                    if (shiftHours != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '${shiftHours.toStringAsFixed(1)} hours × \$${hourlyRate?.toStringAsFixed(2) ?? "0"}/hr',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                    // Tap for details
                                    if (tariffData != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.info_outline_rounded,
                                              size: 14,
                                              color: AppColors.tealDark,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              l10n.tapToViewRateDetails,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: AppColors.tealDark,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: AppColors.tealDark,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
                        title: Text(l10n.uniformRequirements),
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
                        title: Text(l10n.parkingInstructions),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textDark.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status hint for disabled states
                    if (isRoleFull || hasConflict)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isRoleFull ? Icons.group_off_outlined : Icons.schedule_outlined,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isRoleFull
                                  ? 'This role has reached capacity'
                                  : 'You have a scheduling conflict',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Action buttons
                    Row(
                      children: [
                        // Decline button - outlined style
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isResponding
                                ? null
                                : () => _respond(context, theme, 'decline'),
                            icon: _isResponding
                                ? const SizedBox.shrink()
                                : const Icon(Icons.close_rounded, size: 18),
                            label: _isResponding
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.decline),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                color: _isResponding
                                    ? AppColors.borderMedium
                                    : AppColors.error.withOpacity(0.5),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Accept button - filled with success green
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: (_isResponding || isRoleFull || hasConflict)
                                ? null
                                : () => _respond(context, theme, 'accept'),
                            icon: _isResponding
                                ? const SizedBox.shrink()
                                : Icon(
                                    isRoleFull || hasConflict
                                        ? Icons.block_outlined
                                        : Icons.check_rounded,
                                    size: 20,
                                  ),
                            label: _isResponding
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isRoleFull
                                        ? l10n.full
                                        : (hasConflict ? l10n.conflict : l10n.accept),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: (isRoleFull || hasConflict)
                                  ? AppColors.textMuted
                                  : AppColors.success,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.borderMedium,
                              disabledForegroundColor: AppColors.textMuted,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                    color: AppColors.textDark.withOpacity(0.05),
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
                      label: Text(l10n.requestCancellation),
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
    AppLocalizations l10n,
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
        title: Text(l10n.shiftPayRole(role)),
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
                l10n.estimatedTotal,
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
                l10n.basedOnScheduledDuration,
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
            child: Text(l10n.close),
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
                ? (response == 'accept' ? AppColors.success : AppColors.warning)
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
    final l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.requestCancellationQuestion),
        content: const Text(
          'We\'ll let the scheduling team know you can no longer make this event.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.keepEvent),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: Text(l10n.requestCancellationCaps),
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
