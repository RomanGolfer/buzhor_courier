import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/route/services/geocoding_service.dart';
import 'package:buzhor_courier/features/route/services/osrm_route_service.dart';
import 'package:buzhor_courier/features/route/services/route_sorting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

part 'route_detail/route_map_widget.dart';
part 'route_detail/route_header.dart';
part 'route_detail/route_overlay_controls.dart';
part 'route_detail/route_address_search_sheet.dart';
part 'route_detail/route_screen_widgets.dart';
part 'route_detail/route_routing_actions.dart';
part 'route_detail/route_start_point_actions.dart';
part 'route_detail/route_address_search_actions.dart';
part 'route_detail/route_stops_sheet.dart';
part 'route_detail/route_stop_card.dart';

class RouteScreen extends StatefulWidget {
  final List<OrderItem> orders;
  final double? startLat;
  final double? startLng;
  final bool initialLowDataMode;

  const RouteScreen({
    super.key,
    required this.orders,
    this.startLat,
    this.startLng,
    this.initialLowDataMode = false,
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final MapController _mapController;
  late List<OrderItem> _sortedOrders;

  LatLng? _startPoint;
  bool _isGpsStart = false;
  bool _isSearching = false;
  String _searchError = '';

  List<List<LatLng>> _routeSegments = [];
  bool _isLoadingRoute = false;
  bool _isLowDataMode = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _isLowDataMode = widget.initialLowDataMode;
    if (widget.orders.isEmpty) {
      _sortedOrders = [];
    } else if (widget.startLat != null && widget.startLng != null) {
      _startPoint = LatLng(widget.startLat!, widget.startLng!);
      _isGpsStart = true;
      _sortedOrders = RouteSortingService.sortFromLocation(
        widget.orders,
        widget.startLat!,
        widget.startLng!,
      );
    } else {
      _sortedOrders = _sort();
    }
    _fetchRoutes();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _updateRouteState(VoidCallback update) {
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return _RouteEmptyState(onBack: () => Navigator.pop(context));
    }

    final allPoints = [
      ?_startPoint,
      ..._sortedOrders.map((o) => LatLng(o.lat, o.lng)),
    ];
    final centerLat =
        allPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
        allPoints.length;
    final centerLng =
        allPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
        allPoints.length;

    return Scaffold(
      body: Stack(
        children: [
          _RouteMapWidget(
            mapController: _mapController,
            sortedOrders: _sortedOrders,
            startPoint: _startPoint,
            isGpsStart: _isGpsStart,
            isLowDataMode: _isLowDataMode,
            routeSegments: _routeSegments,
            centerLat: centerLat,
            centerLng: centerLng,
            onLongPress: (_, latLng) {
              _setCustomStart(latLng);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Начальная точка обновлена'),
                  backgroundColor: AppColors.darkBlue,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
          _RouteHeader(
            sortedOrders: _sortedOrders,
            startPoint: _startPoint,
            isGpsStart: _isGpsStart,
            centerLat: centerLat,
            centerLng: centerLng,
            mapController: _mapController,
            onBack: () => Navigator.pop(context),
            onSearch: _showAddressSheet,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            right: 16,
            child: _LowDataModeChip(
              enabled: _isLowDataMode,
              onTap: _toggleLowDataMode,
            ),
          ),
          if (_isLoadingRoute) const _RouteLoadingIndicator(),
          if (_startPoint == null) const _RouteStartHint(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _RouteStopsSheet(
              sortedOrders: _sortedOrders,
              onStopTap: (latLng) => _mapController.move(latLng, 16),
            ),
          ),
        ],
      ),
    );
  }
}
