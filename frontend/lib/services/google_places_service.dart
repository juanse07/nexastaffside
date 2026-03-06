import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../auth_service.dart';

/// Lightweight Google Places proxy service for the Staff app.
/// Calls the shared backend endpoints (/api/places/*) — no Google API key
/// needed in the client.
class GooglePlacesService {
  static String get _apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';

  static String get _apiPathPrefix {
    final raw = (dotenv.env['API_PATH_PREFIX'] ?? '').trim();
    if (raw.isEmpty) return '';
    final withLead = raw.startsWith('/') ? raw : '/$raw';
    return withLead.endsWith('/')
        ? withLead.substring(0, withLead.length - 1)
        : withLead;
  }

  /// Get place predictions for autocomplete.
  /// [userLat]/[userLng] bias results towards the user's location.
  static Future<List<PlacePrediction>> getPlacePredictions(
    String input, {
    double? userLat,
    double? userLng,
  }) async {
    if (input.trim().length < 3) return [];

    final token = await AuthService.getJwt();
    if (token == null) return [];

    final body = <String, dynamic>{
      'input': input,
      'biasLat': userLat ?? 39.7392,
      'biasLng': userLng ?? -104.9903,
      'biasRadiusM': 450000,
      'sessionToken': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl$_apiPathPrefix/places/autocomplete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get full place details (formatted address, lat/lng).
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final token = await AuthService.getJwt();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl$_apiPathPrefix/places/details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'placeId': placeId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result'], placeId: placeId);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'] ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] ?? '',
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceDetails.fromJson(
    Map<String, dynamic> json, {
    required String placeId,
  }) {
    final geometry = json['geometry'] ?? {};
    final location = geometry['location'] ?? {};
    return PlaceDetails(
      placeId: placeId,
      formattedAddress: json['formatted_address'] ?? '',
      latitude: (location['lat'] ?? 0.0).toDouble(),
      longitude: (location['lng'] ?? 0.0).toDouble(),
    );
  }
}
