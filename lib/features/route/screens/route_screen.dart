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

  // ─── Routing ─────────────────────────────────────────────────────────────────

  Future<void> _fetchRoutes() async {
    final waypoints = [
      ?_startPoint,
      ..._sortedOrders.map((o) => LatLng(o.lat, o.lng)),
    ];
    if (waypoints.length < 2) {
      if (mounted) setState(() => _routeSegments = []);
      return;
    }
    if (_isLowDataMode) {
      setState(() {
        _routeSegments = [
          for (int i = 0; i < waypoints.length - 1; i++)
            [waypoints[i], waypoints[i + 1]],
        ];
        _isLoadingRoute = false;
      });
      return;
    }
    setState(() => _isLoadingRoute = true);
    final results = await Future.wait([
      for (int i = 0; i < waypoints.length - 1; i++)
        OsrmRouteService.fetchSegment(waypoints[i], waypoints[i + 1]),
    ]);
    if (!mounted) return;
    setState(() {
      _routeSegments = results;
      _isLoadingRoute = false;
    });
  }

  void _toggleLowDataMode() {
    setState(() {
      _isLowDataMode = !_isLowDataMode;
      _routeSegments = [];
      _isLoadingRoute = false;
    });
    _fetchRoutes();
  }

  // ─── Sorting & start point ────────────────────────────────────────────────────

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
    setState(() {
      _startPoint = point;
      _isGpsStart = false;
      _sortedOrders = _sort();
      _routeSegments = [];
    });
    _mapController.move(point, _mapController.camera.zoom);
    _fetchRoutes();
  }

  // ─── Address search ───────────────────────────────────────────────────────────

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchError = '';
    });
    try {
      final point = await GeocodingService.searchAddress(query);
      if (point != null && mounted) {
        Navigator.pop(context);
        _setCustomStart(point);
      } else if (mounted) {
        setState(() => _searchError = 'Адрес не найден');
      }
    } catch (_) {
      if (mounted) setState(() => _searchError = 'Ошибка соединения');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressSearchSheet(
        isSearching: _isSearching,
        searchError: _searchError,
        onSearch: _searchAddress,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.inbox_rounded,
                size: 56,
                color: Color(0xFF8AACCC),
              ),
              const SizedBox(height: 12),
              const Text(
                'Нет активных заказов',
                style: TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Назад',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
          if (_isLoadingRoute)
            const Positioned(
              top: 80,
              right: 16,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.orange,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          if (_startPoint == null)
            Positioned(
              bottom: 220,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Удерживайте карту для выбора точки старта',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
