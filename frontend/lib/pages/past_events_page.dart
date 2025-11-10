import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'event_detail_page.dart';

class PastEventsPage extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;

  const PastEventsPage({
    super.key,
    required this.events,
    required this.userKey,
  });

  @override
  State<PastEventsPage> createState() => _PastEventsPageState();
}

class _PastEventsPageState extends State<PastEventsPage> {
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 1.0;

  // Fade threshold: header starts fading after scrolling this many pixels
  static const double _fadeStartOffset = 50.0;
  // Fade distance: distance over which the fade completes
  static const double _fadeDistance = 100.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;

    // Calculate opacity based on scroll position
    double newOpacity;
    if (offset <= _fadeStartOffset) {
      // Not scrolled far enough - fully visible
      newOpacity = 1.0;
    } else if (offset >= _fadeStartOffset + _fadeDistance) {
      // Scrolled past fade distance - fully invisible
      newOpacity = 0.0;
    } else {
      // In fade zone - calculate proportional opacity
      final fadeProgress = (offset - _fadeStartOffset) / _fadeDistance;
      newOpacity = 1.0 - fadeProgress;
    }

    // Only update if opacity changed significantly (reduces rebuilds)
    if ((newOpacity - _headerOpacity).abs() > 0.01) {
      setState(() {
        _headerOpacity = newOpacity;
      });
    }
  }

  List<Map<String, dynamic>> _filterPastAccepted() {
    if (widget.userKey == null) return const [];
    final List<Map<String, dynamic>> pastEvents = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final e in widget.events) {
      final accepted = e['accepted_staff'];
      if (accepted is List) {
        bool isAccepted = false;
        for (final a in accepted) {
          if (a is String && a == widget.userKey) {
            isAccepted = true;
            break;
          }
          if (a is Map && a['userKey'] == widget.userKey) {
            isAccepted = true;
            break;
          }
        }

        // Only include if accepted AND event is in the past
        if (isAccepted) {
          final eventDate = _parseDateSafe(e['date']?.toString() ?? '');
          if (eventDate != null && eventDate.isBefore(today)) {
            pastEvents.add(e);
          }
        }
      }
    }

    // Sort by date, most recent first
    pastEvents.sort((a, b) {
      final dateA = _parseDateSafe(a['date']?.toString() ?? '');
      final dateB = _parseDateSafe(b['date']?.toString() ?? '');
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // Most recent first
    });

    return pastEvents;
  }

  DateTime? _parseDateSafe(String input) {
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
    final ymd = RegExp(r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$').firstMatch(input);
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

  String _formatEventDateLabel(String? dateStr) {
    final date = _parseDateSafe(dateStr ?? '');
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 30) {
      final weeks = (diff / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[(date.month - 1).clamp(0, 11)];
    return '$month ${date.day}, ${date.year}';
  }

  String _getRoleName(Map<String, dynamic> event) {
    final acc = event['accepted_staff'];
    if (acc is List) {
      for (final a in acc) {
        if (a is Map && a['userKey'] == widget.userKey) {
          final role = a['role']?.toString();
          if (role != null && role.isNotEmpty) {
            return role;
          }
        }
      }
    }
    return '';
  }

  Map<String, List<Map<String, dynamic>>> _groupEventsByMonth(List<Map<String, dynamic>> events) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    for (final event in events) {
      final dateStr = event['date']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;

      final eventDate = _parseDateSafe(dateStr);
      if (eventDate == null) continue;

      // Create month label
      String monthLabel;
      final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

      if (eventDate.year == currentYear && eventDate.month == currentMonth) {
        monthLabel = 'This Month';
      } else if (eventDate.year == currentYear && eventDate.month == currentMonth - 1) {
        monthLabel = 'Last Month';
      } else {
        final month = months[(eventDate.month - 1).clamp(0, 11)];
        if (eventDate.year == currentYear) {
          monthLabel = month;
        } else {
          monthLabel = '$month ${eventDate.year}';
        }
      }

      grouped.putIfAbsent(monthLabel, () => []);
      grouped[monthLabel]!.add(event);
    }

    return grouped;
  }

  List<Widget> _buildMonthlySections(ThemeData theme, List<Map<String, dynamic>> events) {
    final grouped = _groupEventsByMonth(events);
    final sections = <Widget>[];

    // Sort events within each group by date (most recent first)
    grouped.forEach((key, eventsList) {
      eventsList.sort((a, b) {
        final dateA = _parseDateSafe(a['date']?.toString() ?? '');
        final dateB = _parseDateSafe(b['date']?.toString() ?? '');
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA); // Most recent first
      });
    });

    // Sort month labels chronologically (most recent first)
    final sortedKeys = grouped.keys.toList();
    sortedKeys.sort((a, b) {
      final aEvents = grouped[a]!;
      final bEvents = grouped[b]!;
      final aDate = _parseDateSafe(aEvents.first['date']?.toString() ?? '');
      final bDate = _parseDateSafe(bEvents.first['date']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate); // Most recent first
    });

    for (final monthLabel in sortedKeys) {
      final monthEvents = grouped[monthLabel]!;

      // Month header
      sections.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    monthLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${monthEvents.length} ${monthEvents.length == 1 ? 'event' : 'events'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Month events
      sections.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= monthEvents.length) return null;
              final event = monthEvents[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  index == 0 ? 0 : 8,
                  20,
                  8,
                ),
                child: _buildEventCard(context, theme, event),
              );
            },
            childCount: monthEvents.length,
          ),
        ),
      );
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pastEvents = _filterPastAccepted();

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Top padding for safe area
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.of(context).padding.top),
              ),
              // Animated fading header
              SliverToBoxAdapter(
                child: AnimatedOpacity(
                  opacity: _headerOpacity,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6B7280), // Gray
                          Color(0xFF4B5563), // Darker gray
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B7280).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Decorative elements
                          Positioned(
                            top: -30,
                            right: -30,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -40,
                            left: -40,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Past Events',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                          fontSize: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        pastEvents.isEmpty
                                            ? 'No past events'
                                            : '${pastEvents.length} ${pastEvents.length == 1 ? 'event' : 'events'} completed',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Empty state or event list
              if (pastEvents.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                child: Icon(
                                  Icons.history_rounded,
                                  size: 32,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No past events',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your completed events will appear here',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (pastEvents.isNotEmpty)
                ..._buildMonthlySections(theme, pastEvents),
              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
          // Fixed back button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> e,
  ) {
    final eventName = e['event_name']?.toString() ?? 'Untitled Event';
    final clientName = e['client_name']?.toString() ?? '';
    final venue = e['event_name']?.toString() ?? e['venue_name']?.toString() ?? '';
    final venueAddress = e['venue_address']?.toString() ?? '';
    final date = e['date']?.toString() ?? '';
    final role = _getRoleName(e);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailPage(
                  event: e,
                  roleName: role,
                  acceptedEvents: const [],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        role.isNotEmpty ? role : eventName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatEventDateLabel(date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    eventName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (clientName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        clientName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                if (venueAddress.isNotEmpty || venue.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          venueAddress.isNotEmpty ? venueAddress : venue,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
