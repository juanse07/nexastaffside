/// Mock DataService for screenshot mode.
///
/// Extends the real DataService but overrides `initialize()` to be a no-op
/// and populates data directly from fixtures.
library;

import 'package:flutter/foundation.dart';
import '../fixtures/demo_data.dart';

/// A DataService replacement that serves static demo data.
///
/// The real DataService calls `FlutterSecureStorage`, HTTP APIs, and
/// socket.io in its `initialize()`. This mock skips all of that and
/// exposes curated data from [StaffDemoData].
///
/// Because `DataService` from the staff app has private fields and
/// network logic baked in, we create a standalone ChangeNotifier with
/// the same getter interface that root_page.dart consumes.
class MockDataService extends ChangeNotifier {
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _availability = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _myTeams = [];
  List<Map<String, dynamic>> _pendingInvites = [];
  bool _isLoading = false;
  bool _isRefreshing = false;

  // Getters matching DataService's public interface
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  List<Map<String, dynamic>> get availability => List.unmodifiable(_availability);
  List<Map<String, dynamic>> get shifts => List.unmodifiable(_shifts);
  List<Map<String, dynamic>> get teams => List.unmodifiable(_myTeams);
  List<Map<String, dynamic>> get pendingInvites => List.unmodifiable(_pendingInvites);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => null;
  DateTime? get lastFetch => DateTime.now();
  DateTime? get lastShiftsFetch => DateTime.now();
  bool get hasData => _events.isNotEmpty;
  bool get hasShiftsData => _shifts.isNotEmpty;
  bool get isDataFresh => true;
  bool get isAvailabilityFresh => true;

  /// No-op initialization — populates from demo fixtures immediately.
  Future<void> initialize() async {
    _events = StaffDemoData.events;
    _availability = StaffDemoData.availability;
    _shifts = StaffDemoData.events; // Reuse events as shifts
    _myTeams = [];
    _pendingInvites = [];
    _isLoading = false;
    _isRefreshing = false;
    notifyListeners();
  }

  /// No-op refresh
  Future<void> forceRefresh() async {}

  /// No-op
  Future<void> fetchAvailability() async {}

  /// No-op (called by root_page initState)
  Future<void> loadInitialData() async {
    if (_events.isEmpty) await initialize();
  }

  /// No-op (called by root_page on logout)
  Future<void> clearCache() async {}

  /// No-op
  Future<void> refreshIfNeeded() async {}

  /// No-op
  Future<void> invalidateEventsCache() async {}
}
