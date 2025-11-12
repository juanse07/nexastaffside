import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

/// Model class for earnings data
class EarningsData {
  final double yearTotal;
  final List<MonthlyEarnings> monthlyData;
  final Map<String, List<EventEarnings>> monthlyEvents;
  final Map<int, YearlyStats> yearlyStats;  // Year -> Stats

  const EarningsData({
    required this.yearTotal,
    required this.monthlyData,
    required this.monthlyEvents,
    required this.yearlyStats,
  });

  factory EarningsData.empty() {
    return const EarningsData(
      yearTotal: 0.0,
      monthlyData: [],
      monthlyEvents: {},
      yearlyStats: {},
    );
  }

  /// Get list of available years, sorted descending
  List<int> get availableYears {
    final years = yearlyStats.keys.toList()..sort((a, b) => b.compareTo(a));
    return years;
  }
}

/// Model class for yearly statistics
class YearlyStats {
  final int year;
  final double totalEarnings;
  final double totalHours;
  final int totalShifts;
  final Map<String, int> roleBreakdown;  // Role name -> count
  final Map<String, double> roleEarnings;  // Role name -> earnings

  const YearlyStats({
    required this.year,
    required this.totalEarnings,
    required this.totalHours,
    required this.totalShifts,
    required this.roleBreakdown,
    required this.roleEarnings,
  });
}

/// Model class for monthly earnings summary
class MonthlyEarnings {
  final String yearMonth;
  final int year;
  final int monthNum;
  final String monthName;
  final double totalEarnings;
  final double totalHours;
  final int eventCount;

  const MonthlyEarnings({
    required this.yearMonth,
    required this.year,
    required this.monthNum,
    required this.monthName,
    required this.totalEarnings,
    required this.totalHours,
    required this.eventCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'yearMonth': yearMonth,
      'year': year,
      'monthNum': monthNum,
      'month': monthName,
      'totalEarnings': totalEarnings,
      'totalHours': totalHours,
      'eventCount': eventCount,
    };
  }
}

/// Model class for individual event earnings
class EventEarnings {
  final Map<String, dynamic> event;
  final String role;
  final double hours;
  final double rate;
  final double earnings;
  final DateTime date;

  const EventEarnings({
    required this.event,
    required this.role,
    required this.hours,
    required this.rate,
    required this.earnings,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'event': event,
      'role': role,
      'hours': hours,
      'rate': rate,
      'earnings': earnings,
      'date': date,
    };
  }
}

/// Input parameters for earnings calculation (for isolate)
class _EarningsCalculationInput {
  final List<Map<String, dynamic>> events;
  final String userKey;

  const _EarningsCalculationInput({
    required this.events,
    required this.userKey,
  });
}

/// Top-level function for compute() isolate compatibility
/// Optimized algorithm: Pre-filter events and use cached date parsing
Future<EarningsData> _calculateEarningsInIsolate(_EarningsCalculationInput input) async {
  final events = input.events;
  final userKey = input.userKey;

  double yearTotal = 0.0;
  final Map<String, _MonthlyBuilder> monthlyBuilders = {};
  final Map<String, List<EventEarnings>> monthlyEventsList = {};
  final Map<int, _YearlyBuilder> yearlyBuilders = {};
  final now = DateTime.now();

  // Pre-filter events: Only process past events with accepted_staff
  final relevantEvents = <Map<String, dynamic>>[];
  for (final event in events) {
    final acceptedStaff = event['accepted_staff'] as List?;
    if (acceptedStaff == null || acceptedStaff.isEmpty) continue;

    final eventDate = _parseEventDate(event['date']);
    if (eventDate == null || eventDate.isAfter(now)) continue;

    relevantEvents.add(event);
  }

  debugPrint('[EARNINGS-SERVICE] Processing ${relevantEvents.length}/${events.length} relevant events');

  // Process each relevant event (optimized loop structure)
  for (final event in relevantEvents) {
    final eventDate = _parseEventDate(event['date'])!; // Safe - already validated
    final acceptedStaff = event['accepted_staff'] as List;

    // Find user's staff entry (single loop)
    Map<String, dynamic>? userStaff;
    for (final staff in acceptedStaff) {
      if (staff['userKey'] == userKey) {
        userStaff = staff as Map<String, dynamic>;
        break;
      }
    }

    if (userStaff == null) continue;

    final attendance = userStaff['attendance'] as List?;
    if (attendance == null || attendance.isEmpty) continue;

    final staffRole = userStaff['role']?.toString() ?? '';

    // Find hourly rate once per event (cached lookup)
    final hourlyRate = _findHourlyRate(event['roles'] as List?, staffRole);

    // Calculate total approved hours for this event
    double eventTotalHours = 0.0;
    for (final session in attendance) {
      final approvedHours = session['approvedHours'];
      final status = session['status']?.toString();

      if (approvedHours != null && status == 'approved') {
        eventTotalHours += (approvedHours as num).toDouble();
      }
    }

    if (eventTotalHours == 0.0) continue;

    final eventEarnings = eventTotalHours * hourlyRate;
    yearTotal += eventEarnings;

    // Build monthly summary
    final yearMonth = '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}';

    final monthBuilder = monthlyBuilders.putIfAbsent(
      yearMonth,
      () => _MonthlyBuilder(
        yearMonth: yearMonth,
        year: eventDate.year,
        monthNum: eventDate.month,
        monthName: _getMonthName(eventDate.month),
      ),
    );

    monthBuilder.addEarnings(eventEarnings, eventTotalHours);
    monthBuilder.addEventId(event['_id']?.toString() ?? event['id']?.toString() ?? '');

    // Build yearly statistics
    final yearBuilder = yearlyBuilders.putIfAbsent(
      eventDate.year,
      () => _YearlyBuilder(year: eventDate.year),
    );
    yearBuilder.addShift(staffRole, eventEarnings, eventTotalHours);

    // Store event details for monthly breakdown
    final eventEarning = EventEarnings(
      event: event,
      role: staffRole,
      hours: eventTotalHours,
      rate: hourlyRate,
      earnings: eventEarnings,
      date: eventDate,
    );

    monthlyEventsList.putIfAbsent(yearMonth, () => []).add(eventEarning);
  }

  // Convert builders to sorted list
  final monthlyData = monthlyBuilders.values
      .map((builder) => builder.build())
      .toList();

  // Sort by year-month descending (most recent first)
  monthlyData.sort((a, b) => b.yearMonth.compareTo(a.yearMonth));

  // Sort events within each month by date descending
  monthlyEventsList.forEach((key, events) {
    events.sort((a, b) => b.date.compareTo(a.date));
  });

  // Build yearly stats map
  final yearlyStats = <int, YearlyStats>{};
  yearlyBuilders.forEach((year, builder) {
    yearlyStats[year] = builder.build();
  });

  debugPrint('[EARNINGS-SERVICE] Calculation complete - total: \$${yearTotal.toStringAsFixed(2)}, months: ${monthlyData.length}, years: ${yearlyStats.length}');

  return EarningsData(
    yearTotal: yearTotal,
    monthlyData: monthlyData,
    monthlyEvents: monthlyEventsList,
    yearlyStats: yearlyStats,
  );
}

/// Helper class for building monthly summaries efficiently
class _MonthlyBuilder {
  final String yearMonth;
  final int year;
  final int monthNum;
  final String monthName;
  double totalEarnings = 0.0;
  double totalHours = 0.0;
  final Set<String> eventIds = {};

  _MonthlyBuilder({
    required this.yearMonth,
    required this.year,
    required this.monthNum,
    required this.monthName,
  });

  void addEarnings(double earnings, double hours) {
    totalEarnings += earnings;
    totalHours += hours;
  }

  void addEventId(String id) {
    if (id.isNotEmpty) eventIds.add(id);
  }

  MonthlyEarnings build() {
    return MonthlyEarnings(
      yearMonth: yearMonth,
      year: year,
      monthNum: monthNum,
      monthName: monthName,
      totalEarnings: totalEarnings,
      totalHours: totalHours,
      eventCount: eventIds.length,
    );
  }
}

/// Helper class for building yearly statistics efficiently
class _YearlyBuilder {
  final int year;
  double totalEarnings = 0.0;
  double totalHours = 0.0;
  int totalShifts = 0;
  final Map<String, int> roleBreakdown = {};  // Role name -> shift count
  final Map<String, double> roleEarnings = {};  // Role name -> total earnings

  _YearlyBuilder({required this.year});

  void addShift(String role, double earnings, double hours) {
    totalEarnings += earnings;
    totalHours += hours;
    totalShifts++;

    // Track role statistics
    if (role.isNotEmpty) {
      roleBreakdown[role] = (roleBreakdown[role] ?? 0) + 1;
      roleEarnings[role] = (roleEarnings[role] ?? 0.0) + earnings;
    }
  }

  YearlyStats build() {
    return YearlyStats(
      year: year,
      totalEarnings: totalEarnings,
      totalHours: totalHours,
      totalShifts: totalShifts,
      roleBreakdown: Map.unmodifiable(roleBreakdown),
      roleEarnings: Map.unmodifiable(roleEarnings),
    );
  }
}

/// Find hourly rate for a role (optimized lookup)
double _findHourlyRate(List<dynamic>? roles, String targetRole) {
  if (roles == null) return 0.0;

  for (final role in roles) {
    if (role['role']?.toString() == targetRole) {
      final tariff = role['tariff'];
      if (tariff != null && tariff['rate'] != null) {
        return (tariff['rate'] as num).toDouble();
      }
    }
  }

  return 0.0;
}

/// Parse event date with caching potential
DateTime? _parseEventDate(dynamic date) {
  if (date == null) return null;
  try {
    if (date is DateTime) return date;
    return DateTime.parse(date.toString());
  } catch (e) {
    return null;
  }
}

/// Get month name from number
String _getMonthName(int month) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return months[month - 1];
}

/// Service for managing earnings calculations with caching and background processing
class EarningsService extends ChangeNotifier {
  EarningsData _cachedData = EarningsData.empty();
  String? _cachedEventsHash;
  bool _isCalculating = false;
  DateTime? _lastCalculationTime;

  EarningsData get data => _cachedData;
  bool get isCalculating => _isCalculating;
  bool get hasData => _cachedData.yearTotal > 0 || _cachedData.monthlyData.isNotEmpty;
  DateTime? get lastCalculationTime => _lastCalculationTime;

  /// Calculate earnings with smart caching
  /// Only recalculates if events list has actually changed
  Future<void> calculateEarnings(
    List<Map<String, dynamic>> events,
    String userKey, {
    bool forceRecalculation = false,
  }) async {
    // Generate hash of events list to detect changes
    final eventsHash = _generateEventsHash(events);

    // Skip calculation if data hasn't changed
    if (!forceRecalculation &&
        _cachedEventsHash == eventsHash &&
        _cachedData.yearTotal >= 0) {
      debugPrint('[EARNINGS-SERVICE] Using cached data (hash unchanged)');
      return;
    }

    if (_isCalculating) {
      debugPrint('[EARNINGS-SERVICE] Calculation already in progress, skipping');
      return;
    }

    _isCalculating = true;
    notifyListeners();

    try {
      debugPrint('[EARNINGS-SERVICE] Starting background calculation...');
      final startTime = DateTime.now();

      // Run calculation in background isolate
      final input = _EarningsCalculationInput(
        events: events,
        userKey: userKey,
      );

      final result = await compute(_calculateEarningsInIsolate, input);

      final duration = DateTime.now().difference(startTime);
      debugPrint('[EARNINGS-SERVICE] Calculation completed in ${duration.inMilliseconds}ms');

      _cachedData = result;
      _cachedEventsHash = eventsHash;
      _lastCalculationTime = DateTime.now();

    } catch (e) {
      debugPrint('[EARNINGS-SERVICE] Calculation error: $e');
      _cachedData = EarningsData.empty();
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  /// Get events for a specific month (from cache)
  List<EventEarnings> getMonthlyEvents(String yearMonth) {
    return _cachedData.monthlyEvents[yearMonth] ?? [];
  }

  /// Invalidate cache to force recalculation
  void invalidateCache() {
    _cachedEventsHash = null;
    debugPrint('[EARNINGS-SERVICE] Cache invalidated');
  }

  /// Generate hash of events list to detect changes
  /// Uses event IDs and update timestamps if available
  String _generateEventsHash(List<Map<String, dynamic>> events) {
    // Create a lightweight representation of events for hashing
    final ids = events.map((e) {
      final id = e['_id']?.toString() ?? e['id']?.toString() ?? '';
      final updated = e['updated_at']?.toString() ?? e['updatedAt']?.toString() ?? '';
      return '$id:$updated';
    }).join('|');

    return md5.convert(utf8.encode(ids)).toString();
  }
}
