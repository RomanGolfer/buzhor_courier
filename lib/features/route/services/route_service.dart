import 'package:buzhor_courier/features/orders/models/order_item.dart';

class RouteService {
  static List<OrderItem> nearestNeighborSort(
    List<OrderItem> orders,
    double startLat,
    double startLng,
  ) {
    final remaining = List<OrderItem>.from(orders);
    final result = <OrderItem>[];

    double currentLat = startLat;
    double currentLng = startLng;

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final da = _sqCoord(currentLat, currentLng, a.lat, a.lng);
        final db = _sqCoord(currentLat, currentLng, b.lat, b.lng);
        return da.compareTo(db);
      });

      final next = remaining.removeAt(0);
      result.add(next);

      currentLat = next.lat;
      currentLng = next.lng;
    }

    return result;
  }

  static double _sqCoord(double lat1, double lng1, double lat2, double lng2) {
    final dx = lat1 - lat2;
    final dy = lng1 - lng2;
    return dx * dx + dy * dy;
  }
}
