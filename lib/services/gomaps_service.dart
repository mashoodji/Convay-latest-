// lib/services/route_service.dart
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RouteService {
  // GoMaps Directions endpoint
  static const String _baseUrl =
      'https://maps.gomaps.pro/maps/api/directions/json';
  final String apiKey;

  RouteService(this.apiKey);

  /// Fetches direction data from GoMaps (Google-compatible JSON).
  /// Returns the full JSON Map if status == "OK"; otherwise null.
  Future<Map<String, dynamic>?> getRouteDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
    bool alternatives = false,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?'
            'origin=${origin.latitude},${origin.longitude}&'
            'destination=${destination.latitude},${destination.longitude}&'
            'mode=$mode&'
            'alternatives=$alternatives&'
            'key=$apiKey',
      );

      print('[RouteService] Requesting: $url');
      final response = await http.get(url);

      print('[RouteService] Status: ${response.statusCode}');
      print('[RouteService] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          return data;
        } else {
          print(
              '[RouteService] Directions API returned status: ${data['status']}');
          return null;
        }
      } else {
        print(
            '[RouteService] HTTP ${response.statusCode} → ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      print('[RouteService] Exception while fetching directions: $e');
      return null;
    }
  }

  /// Decodes either overview_polyline.points or (if absent) concatenates
  /// all leg→step→polyline.points and decodes them in order.
  List<LatLng> extractPolyline(Map<String, dynamic> directionsJson) {
    final routes = directionsJson['routes'] as List<dynamic>;
    if (routes.isEmpty) return [];

    final firstRoute = routes[0] as Map<String, dynamic>;

    // 1) If "overview_polyline" is present, decode that directly:
    if (firstRoute.containsKey('overview_polyline') &&
        (firstRoute['overview_polyline'] as Map).containsKey('points')) {
      final String encoded = firstRoute['overview_polyline']['points'];
      return _decodeEncodedPolyline(encoded);
    }

    // 2) Otherwise, stitch together all step→polyline points:
    final List<LatLng> allPoints = [];
    final legs = firstRoute['legs'] as List<dynamic>;
    for (final leg in legs) {
      final steps = (leg as Map<String, dynamic>)['steps'] as List<dynamic>;
      for (final step in steps) {
        final polylineMap = (step as Map<String, dynamic>)['polyline'];
        if (polylineMap != null && polylineMap['points'] != null) {
          final String stepEncoded = polylineMap['points'] as String;
          allPoints.addAll(_decodeEncodedPolyline(stepEncoded));
        }
      }
    }
    return allPoints;
  }

  /// Returns total distance (in meters) and duration (in seconds) from JSON.
  /// If JSON is missing these, returns null for that field.
  ///
  /// Assumes “routes[0].legs[0].distance.value” and “routes[0].legs[0].duration.value”
  Map<String, dynamic> extractDistanceAndDuration(
      Map<String, dynamic> directionsJson) {
    final routes = directionsJson['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      return {'distance_m': null, 'duration_s': null};
    }

    final firstRoute = routes[0] as Map<String, dynamic>;
    final legs = (firstRoute['legs'] as List<dynamic>);
    if (legs.isEmpty) {
      return {'distance_m': null, 'duration_s': null};
    }

    final firstLeg = legs[0] as Map<String, dynamic>;
    final distanceValue = (firstLeg['distance'] as Map<String, dynamic>)['value'];
    final durationValue = (firstLeg['duration'] as Map<String, dynamic>)['value'];
    return {
      'distance_m': distanceValue as int,
      'duration_s': durationValue as int,
    };
  }

  /// Helper: Decodes a single encoded polyline string into a list of LatLng.
  List<LatLng> _decodeEncodedPolyline(String encoded) {
    final polylinePoints = PolylinePoints();
    final List<PointLatLng> decoded = polylinePoints.decodePolyline(encoded);
    return decoded
        .map((pt) => LatLng(pt.latitude, pt.longitude))
        .toList();
  }
}
