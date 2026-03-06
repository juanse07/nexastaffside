import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of a single commute calculation.
class CommuteResult {
  final double distanceMiles;
  final int durationMinutes;

  const CommuteResult({
    required this.distanceMiles,
    required this.durationMinutes,
  });
}

/// Computes real driving distances using:
///   1. Nominatim (OSM) for venue geocoding
///   2. OSRM (router.project-osrm.org) for actual road routing
///
/// Results are stored in a static in-memory cache so shift cards
/// pre-populate commute data which the AI sheet can read instantly
/// without making any HTTP calls at analysis time.
class CommuteService {
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _osrmBase = 'https://router.project-osrm.org';
  static const _userAgent = 'FlowShiftApp/1.0';
  static const _timeout = Duration(seconds: 10);

  // Static cache: venueAddress → result (null = lookup failed / no result)
  static final Map<String, CommuteResult?> _cache = {};
  // Tracks in-flight lookups to avoid duplicate concurrent requests
  static final Set<String> _pending = {};

  static CommuteResult? getCached(String venueAddress) =>
      _cache[venueAddress];

  static bool isCached(String venueAddress) =>
      _cache.containsKey(venueAddress);

  static bool isPending(String venueAddress) =>
      _pending.contains(venueAddress);

  /// Returns all cached results as a map — used by AI context builder.
  static Map<String, CommuteResult> get allCached =>
      Map.fromEntries(_cache.entries.whereType<MapEntry<String, CommuteResult>>());

  /// Geocode [address] → (lat, lng) via Nominatim.
  static Future<({double lat, double lng})?> geocode(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final uri = Uri.parse('$_nominatimBase/search').replace(
        queryParameters: {
          'q': address.trim(),
          'format': 'json',
          'limit': '1',
        },
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': _userAgent, 'Accept-Language': 'en'})
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final list = json.decode(resp.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lng = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }

  /// Get driving distance and time via OSRM.
  static Future<CommuteResult?> route({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final uri = Uri.parse(
        '$_osrmBase/route/v1/driving/'
        '$originLng,$originLat;$destLng,$destLat'
        '?overview=false',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final first = routes.first as Map<String, dynamic>;
      final distanceMeters = (first['distance'] as num?)?.toDouble() ?? 0.0;
      final durationSeconds = (first['duration'] as num?)?.toDouble() ?? 0.0;
      return CommuteResult(
        distanceMiles: distanceMeters / 1609.344,
        durationMinutes: (durationSeconds / 60).round(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Geocode [venueAddress] then route from home coordinates.
  /// Stores result in static cache. Safe to call multiple times for the
  /// same address — deduplicates in-flight requests automatically.
  static Future<CommuteResult?> commuteFromHome({
    required double homeLat,
    required double homeLng,
    required String venueAddress,
  }) async {
    final key = venueAddress.trim();
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];
    if (_pending.contains(key)) return null; // already in flight

    _pending.add(key);
    try {
      // Try full address first; if geocoding fails, retry without the first
      // comma-separated segment (strips venue-name prefixes like
      // "Cherokee Ranch & Castle, North Daniels Park Road, Sedalia, CO").
      var coords = await geocode(key);
      if (coords == null) {
        final commaIdx = key.indexOf(',');
        if (commaIdx > 0) {
          final stripped = key.substring(commaIdx + 1).trim();
          coords = await geocode(stripped);
          if (coords != null) {
            debugPrint('[Commute] Geocode succeeded with stripped address: $stripped');
          }
        }
      }
      if (coords == null) {
        _cache[key] = null;
        debugPrint('[Commute] Geocode failed for: $key');
        return null;
      }
      final result = await route(
        originLat: homeLat,
        originLng: homeLng,
        destLat: coords.lat,
        destLng: coords.lng,
      );
      _cache[key] = result;
      debugPrint('[Commute] $key → ${result?.distanceMiles.toStringAsFixed(1)} mi, ${result?.durationMinutes} min');
      return result;
    } catch (e) {
      _cache[key] = null;
      debugPrint('[Commute] Error for $key: $e');
      return null;
    } finally {
      _pending.remove(key);
    }
  }

  /// Clear cached results (e.g. when home address changes).
  static void clearCache() {
    _cache.clear();
    _pending.clear();
  }
}
