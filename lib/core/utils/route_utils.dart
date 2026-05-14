import 'package:buzhor_courier/features/orders/models/order_item.dart';

class RouteUtils {
  static List<OrderItem> nearestNeighborSort(
    List<OrderItem> orders,
    double startLat,
    double startLng,
  ) {
    if (orders.isEmpty) return [];

    final remaining = List<OrderItem>.from(orders);
    final result = <OrderItem>[];

    var bestIdx = 0;
    var bestDist = _sq(startLat, startLng, remaining[0].lat, remaining[0].lng);
    for (var i = 1; i < remaining.length; i++) {
      final d = _sq(startLat, startLng, remaining[i].lat, remaining[i].lng);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    result.add(remaining.removeAt(bestIdx));

    while (remaining.isNotEmpty) {
      final last = result.last;
      var nIdx = 0;
      var nDist = _sq(last.lat, last.lng, remaining[0].lat, remaining[0].lng);
      for (var i = 1; i < remaining.length; i++) {
        final d = _sq(last.lat, last.lng, remaining[i].lat, remaining[i].lng);
        if (d < nDist) {
          nDist = d;
          nIdx = i;
        }
      }
      result.add(remaining.removeAt(nIdx));
    }

    return result;
  }

  static double _sq(double lat1, double lng1, double lat2, double lng2) {
    final dl = lat1 - lat2, dn = lng1 - lng2;
    return dl * dl + dn * dn;
  }
}
