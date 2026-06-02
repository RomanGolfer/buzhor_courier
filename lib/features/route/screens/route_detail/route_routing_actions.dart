part of '../route_screen.dart';

extension _RouteRoutingActions on _RouteScreenState {
  Future<void> _fetchRoutes() async {
    final waypoints = [
      ?_startPoint,
      ..._sortedOrders.map((o) => LatLng(o.lat, o.lng)),
    ];
    if (waypoints.length < 2) {
      if (mounted) _updateRouteState(() => _routeSegments = []);
      return;
    }
    if (_isLowDataMode) {
      _updateRouteState(() {
        _routeSegments = [
          for (int i = 0; i < waypoints.length - 1; i++)
            [waypoints[i], waypoints[i + 1]],
        ];
        _isLoadingRoute = false;
      });
      return;
    }
    _updateRouteState(() => _isLoadingRoute = true);
    final results = await Future.wait([
      for (int i = 0; i < waypoints.length - 1; i++)
        OsrmRouteService.fetchSegment(waypoints[i], waypoints[i + 1]),
    ]);
    if (!mounted) return;
    _updateRouteState(() {
      _routeSegments = results;
      _isLoadingRoute = false;
    });
  }

  void _toggleLowDataMode() {
    _updateRouteState(() {
      _isLowDataMode = !_isLowDataMode;
      _routeSegments = [];
      _isLoadingRoute = false;
    });
    _fetchRoutes();
  }
}
