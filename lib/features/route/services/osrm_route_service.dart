import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmRouteService {
  static const _host = 'router.project-osrm.org';
  static const _timeout = Duration(seconds: 8);

  OsrmRouteService._();

  static Future<List<LatLng>> fetchSegment(
    LatLng from,
    LatLng to, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final response = await httpClient
          .get(_segmentUri(from, to))
          .timeout(_timeout);

      if (response.statusCode != 200) return _fallback(from, to);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return _fallback(from, to);

      final geometry = routes.first as Map<String, dynamic>;
      final geometryData = geometry['geometry'] as Map<String, dynamic>?;
      final coords = geometryData?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) return _fallback(from, to);

      return coords.map((c) {
        final pair = c as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();
    } catch (_) {
      return _fallback(from, to);
    } finally {
      if (shouldCloseClient) httpClient.close();
    }
  }

  static Uri _segmentUri(LatLng from, LatLng to) {
    return Uri.https(
      _host,
      '/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      const {'overview': 'full', 'geometries': 'geojson'},
    );
  }

  static List<LatLng> _fallback(LatLng from, LatLng to) => [from, to];
}
