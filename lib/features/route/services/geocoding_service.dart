import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service for geocoding addresses using Nominatim OpenStreetMap API
class GeocodingService {
  static const String _baseUrl = 'nominatim.openstreetmap.org';
  static const String _userAgent = 'BuzhorCourier/1.0';
  static const Duration _timeout = Duration(seconds: 8);

  /// Search for an address and return its coordinates
  /// Returns null if address not found or an error occurs
  static Future<LatLng?> searchAddress(String query) async {
    if (query.trim().isEmpty) return null;

    try {
      final uri = Uri.https(_baseUrl, '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
        'countrycodes': 'ru',
      });

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        // Ensure proper UTF-8 decoding for Cyrillic text
        final decoded = utf8.decode(response.bodyBytes);
        final data = json.decode(decoded) as List;
        
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'] as String);
          final lon = double.parse(data[0]['lon'] as String);
          return LatLng(lat, lon);
        }
      }
    } catch (_) {
      // Return null on any error (timeout, network, parsing, etc.)
    }

    return null;
  }
}
