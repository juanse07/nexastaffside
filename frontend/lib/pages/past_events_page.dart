import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'event_detail_page.dart';
import '../utils/accepted_staff.dart';
import '../l10n/app_localizations.dart';

class PastEventsPage extends StatefulWidget {
  final List<Map<String, dynamic>> events; // Now contains shifts data
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

  // Pagination state
  int _displayCount = 20;
  static const int _pageSize = 20;

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

  void _loadMoreEvents() {
    setState(() {
      _displayCount += _pageSize;
    });
  }

  List<Map<String, dynamic>> _filterPastAccepted() {
    if (widget.userKey == null) return const [];
    final List<Map<String, dynamic>> pastEvents = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    debugPrint('=== PAST EVENTS FILTER DEBUG ===');
    debugPrint('UserKey: ${widget.userKey}');
    debugPrint('Today: $today');
    debugPrint('Total events to check: ${widget.events.length}');

    for (final e in widget.events) {
      final eventId = e['_id'] ?? e['id'];
      final eventName = e['event_name'] ?? 'No name';
      final acceptedEntry = findAcceptedStaffEntry(e, widget.userKey);

      debugPrint('Checking event: $eventId - $eventName');
      debugPrint('  Date: ${e['date']}');
      debugPrint('  Status: ${e['status']}');
      debugPrint('  Accepted entry found: ${acceptedEntry != null}');

      if (acceptedEntry != null) {
        final eventDate = _parseDateSafe(e['date']?.toString() ?? '');
        debugPrint('  Event date parsed: $eventDate');

        if (eventDate != null) {
          final isPast = eventDate.isBefore(today);
          debugPrint('  Is event before today: $isPast');

          if (isPast) {
            pastEvents.add(e);
            debugPrint('  ✅ Added to past events!');
          } else {
            debugPrint('  ❌ Skipped - not past');
          }
        } else {
          debugPrint('  ❌ Skipped - could not parse date');
        }
      } else {
        debugPrint('  ❌ Skipped - user not accepted');
      }
    }

    debugPrint('=== FINAL PAST EVENTS COUNT: ${pastEvents.length} ===');
    debugPrint('=====================================');

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

  String _formatEventDateLabel(BuildContext context, String? dateStr) {
    final l10n = AppLocalizations.of(context)!;
    final date = _parseDateSafe(dateStr ?? '');
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return l10n.today;
    if (diff == 1) return l10n.yesterday;
    if (diff < 7) return l10n.daysAgo(diff);
    if (diff < 30) {
      final weeks = (diff / 7).floor();
      return weeks == 1 ? l10n.weekAgo : l10n.weeksAgo(weeks);
    }

    final months = [l10n.jan, l10n.feb, l10n.mar, l10n.apr, l10n.may, l10n.jun, l10n.jul, l10n.aug, l10n.sep, l10n.oct, l10n.nov, l10n.dec];
    final month = months[(date.month - 1).clamp(0, 11)];
    return '$month ${date.day}, ${date.year}';
  }

  String _getRoleName(Map<String, dynamic> event) {
    final acc = event['accepted_staff'];
    if (acc is List) {
      final userKeyNumeric = widget.userKey?.split(':').last;
      for (final a in acc) {
        if (a is Map && (a['userKey'] == widget.userKey || a['userKey'] == userKeyNumeric ||
                        a['sub'] == widget.userKey || a['sub'] == userKeyNumeric)) {
          final role = a['role']?.toString();
          if (role != null && role.isNotEmpty) {
            return role;
          }
        }
      }
    }
    return '';
  }

  Map<String, List<Map<String, dynamic>>> _groupEventsByMonth(BuildContext context, List<Map<String, dynamic>> events) {
    final l10n = AppLocalizations.of(context)!;
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
      final months = [l10n.january, l10n.february, l10n.march, l10n.april, l10n.mayFull, l10n.june, l10n.july, l10n.august, l10n.september, l10n.october, l10n.november, l10n.december];

      if (eventDate.year == currentYear && eventDate.month == currentMonth) {
        monthLabel = l10n.thisMonth;
      } else if (eventDate.year == currentYear && eventDate.month == currentMonth - 1) {
        monthLabel = l10n.lastMonth;
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

  List<Widget> _buildMonthlySections(BuildContext context, ThemeData theme, List<Map<String, dynamic>> events) {
    final l10n = AppLocalizations.of(context)!;
    final grouped = _groupEventsByMonth(context, events);
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
                  monthEvents.length == 1
                      ? l10n.eventAccepted(monthEvents.length)
                      : '${monthEvents.length} ${l10n.events}',
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
    final l10n = AppLocalizations.of(context)!;

    debugPrint('🔍 [PAST_EVENTS] Building with ${widget.events.length} events');
    debugPrint('🔍 [PAST_EVENTS] UserKey: ${widget.userKey}');

    final allPastEvents = _filterPastAccepted();
    final displayedEvents = allPastEvents.take(_displayCount).toList();
    final hasMoreEvents = allPastEvents.length > _displayCount;

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
                                        l10n.myEvents,
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                          fontSize: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        allPastEvents.isEmpty
                                            ? l10n.noAcceptedEvents
                                            : (allPastEvents.length == 1
                                                ? l10n.eventAccepted(allPastEvents.length)
                                                : l10n.eventsAccepted(allPastEvents.length)),
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
              if (allPastEvents.isEmpty)
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
                                l10n.noPastEvents,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.completedEventsWillAppearHere,
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
              if (allPastEvents.isNotEmpty)
                ..._buildMonthlySections(context, theme, displayedEvents),
              // Load More button
              if (hasMoreEvents)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Center(
                      child: OutlinedButton.icon(
                        onPressed: _loadMoreEvents,
                        icon: const Icon(Icons.expand_more, size: 20),
                        label: Text(
                          l10n.loadMoreEvents((allPastEvents.length - _displayCount).clamp(0, _pageSize)),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.5),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
    final l10n = AppLocalizations.of(context)!;
    final eventName = e['shift_name']?.toString() ?? e['event_name']?.toString() ?? l10n.untitledEvent;
    final clientName = e['client_name']?.toString() ?? '';
    final venue = e['venue_name']?.toString() ?? '';
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
                        _formatEventDateLabel(context, date),
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
