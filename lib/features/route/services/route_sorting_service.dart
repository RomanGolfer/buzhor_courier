import 'package:buzhor_courier/features/orders/models/order_item.dart';

/// Service for sorting orders using nearest-neighbor algorithm
class RouteSortingService {
  /// Sort orders using nearest-neighbor greedy algorithm
  /// Starts from the given coordinates and builds an ordered route
  static List<OrderItem> sortFromLocation(
    List<OrderItem> orders,
    double startLat,
    double startLng,
  ) {
    if (orders.isEmpty) return [];

    final remaining = List<OrderItem>.from(orders);
    final result = <OrderItem>[];

    // Find nearest order to start point
    var bestIdx = 0;
    var bestDist = _squaredDistance(startLat, startLng, remaining[0].lat, remaining[0].lng);
    for (var i = 1; i < remaining.length; i++) {
      final d = _squaredDistance(startLat, startLng, remaining[i].lat, remaining[i].lng);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    result.add(remaining.removeAt(bestIdx));

    // Greedily add next nearest order to current position
    while (remaining.isNotEmpty) {
      final last = result.last;
      var nIdx = 0;
      var nDist = _squaredDistance(last.lat, last.lng, remaining[0].lat, remaining[0].lng);
      for (var i = 1; i < remaining.length; i++) {
        final d = _squaredDistance(last.lat, last.lng, remaining[i].lat, remaining[i].lng);
        if (d < nDist) {
          nDist = d;
          nIdx = i;
        }
      }
      result.add(remaining.removeAt(nIdx));
    }

    return result;
  }

  /// Calculate squared distance between two lat/lng points
  /// (faster than actual distance for comparison purposes)
  static double _squaredDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dlat = lat1 - lat2;
    final dlng = lng1 - lng2;
    return dlat * dlat + dlng * dlng;
  }
}
