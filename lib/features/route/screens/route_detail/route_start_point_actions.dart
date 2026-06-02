part of '../route_screen.dart';

extension _RouteStartPointActions on _RouteScreenState {
  List<OrderItem> _sort() {
    if (widget.orders.isEmpty) return [];
    final start = _startPoint;
    if (start != null) {
      return RouteSortingService.sortFromLocation(
        widget.orders,
        start.latitude,
        start.longitude,
      );
    }
    return RouteSortingService.sortFromLocation(
      widget.orders,
      widget.orders.first.lat,
      widget.orders.first.lng,
    );
  }

  void _setCustomStart(LatLng point) {
    _updateRouteState(() {
      _startPoint = point;
      _isGpsStart = false;
      _sortedOrders = _sort();
      _routeSegments = [];
    });
    _mapController.move(point, _mapController.camera.zoom);
    _fetchRoutes();
  }
}
