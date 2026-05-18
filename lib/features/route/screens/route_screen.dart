import 'dart:convert';

import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/features/route/services/geocoding_service.dart';
import 'package:buzhor_courier/features/route/services/route_sorting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteScreen extends StatefulWidget {
  final List<OrderItem> orders;
  final double? startLat;
  final double? startLng;

  const RouteScreen({
    super.key,
    required this.orders,
    this.startLat,
    this.startLng,
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final MapController _mapController;
  late List<OrderItem> _sortedOrders;

  LatLng? _startPoint; // GPS or custom start
  bool _isGpsStart = false;
  bool _isSearching = false;
  String _searchError = '';

  List<List<LatLng>> _routeSegments = [];
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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

  // ─── OSRM ROUTING ───────────────────────────────────────────────────────────

  Future<List<LatLng>> _fetchOsrmSegment(LatLng from, LatLng to) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coords =
            data['routes'][0]['geometry']['coordinates'] as List<dynamic>;
        return coords
            .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList();
      }
    } catch (_) {}
    return [from, to]; // straight-line fallback
  }

  Future<void> _fetchRoutes() async {
    final waypoints = [
      ?_startPoint,
      ..._sortedOrders.map((o) => LatLng(o.lat, o.lng)),
    ];
    if (waypoints.length < 2) return;

    setState(() => _isLoadingRoute = true);

    final results = await Future.wait([
      for (int i = 0; i < waypoints.length - 1; i++)
        _fetchOsrmSegment(waypoints[i], waypoints[i + 1]),
    ]);

    if (!mounted) return;
    setState(() {
      _routeSegments = results;
      _isLoadingRoute = false;
    });
  }

  // ─── SORTING ────────────────────────────────────────────────────────────────

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
    // No start point: nearest-neighbor from first order
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

  // ─── ADDRESS SEARCH ─────────────────────────────────────────────────────────

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final point = await GeocodingService.searchAddress(query);
      if (point != null && mounted) {
        Navigator.pop(context); // close sheet
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
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6E4F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Начальная точка',
                      style: TextStyle(
                        color: AppColors.darkBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Введите адрес или долгим нажатием на карте',
                      style: TextStyle(
                        color: const Color(0xFF6B8CAE).withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                      ),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        style: const TextStyle(
                          color: AppColors.darkBlue,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ул. Крымская, 45, Анапа',
                          hintStyle: TextStyle(color: Color(0xFF8AACCC)),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF8AACCC),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (v) {
                          _searchAddress(v);
                        },
                      ),
                    ),
                    if (_searchError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _searchError,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: GestureDetector(
                        onTap: () {
                          _searchAddress(controller.text);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.blue, AppColors.lightBlue],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isSearching
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Text(
                                    'Найти',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

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

    final points = _sortedOrders.map((o) => LatLng(o.lat, o.lng)).toList();
    final allPoints = [?_startPoint, ...points];
    final centerLat =
        allPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
        allPoints.length;
    final centerLng =
        allPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
        allPoints.length;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(centerLat, centerLng),
              initialZoom: 14.5,
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
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              SimpleAttributionWidget(source: const Text('CartoDB')),
              // Road-following route polylines from OSRM
              if (_routeSegments.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (int i = 0; i < _routeSegments.length; i++)
                      Polyline(
                        points: _routeSegments[i],
                        color: (_startPoint != null && i == 0)
                            ? AppColors.blue.withValues(alpha: 0.5)
                            : AppColors.orange,
                        strokeWidth: (_startPoint != null && i == 0)
                            ? 2.5
                            : 3.5,
                        pattern: (_startPoint != null && i == 0)
                            ? StrokePattern.dashed(segments: const [8, 6])
                            : const StrokePattern.solid(),
                      ),
                  ],
                ),
              // Start marker
              if (_startPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _startPoint!,
                      width: 36,
                      height: 36,
                      child: _StartMarker(isGps: _isGpsStart),
                    ),
                  ],
                ),
              // Stop markers
              MarkerLayer(
                markers: List.generate(_sortedOrders.length, (i) {
                  final o = _sortedOrders[i];
                  return Marker(
                    point: LatLng(o.lat, o.lng),
                    width: 32,
                    height: 32,
                    child: _StopMarker(number: i + 1, isDone: o.isDone),
                  );
                }),
              ),
            ],
          ),

          // ── Top bar ────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _MapBtn(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: AppColors.darkBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.route_rounded,
                            color: AppColors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _startPoint == null
                                  ? '${_sortedOrders.length} остановок'
                                  : '${_isGpsStart ? 'GPS' : 'Своя точка'} · ${_sortedOrders.length} остановок',
                              style: const TextStyle(
                                color: AppColors.darkBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MapBtn(
                    onTap: _showAddressSheet,
                    child: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.darkBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MapBtn(
                    onTap: () =>
                        _mapController.move(LatLng(centerLat, centerLng), 14.5),
                    child: const Icon(
                      Icons.center_focus_strong_rounded,
                      size: 20,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Route loading indicator ───────────────────────────────────────
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

          // ── Long-press hint (shown until custom start is set) ──────────────
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

          // ── Bottom stop summary ────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStopSummary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStopSummary(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final remaining = _sortedOrders
        .where((o) => !o.isDone)
        .fold<int>(0, (s, o) => s + o.bottles);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD6E4F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Остановки',
                  style: TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (remaining > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$remaining бут. осталось',
                      style: const TextStyle(
                        color: AppColors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 144,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              itemCount: _sortedOrders.length,
              itemBuilder: (_, i) => _buildStopCard(_sortedOrders[i], i + 1),
            ),
          ),
          SizedBox(height: bottomPadding + 10),
        ],
      ),
    );
  }

  Widget _buildStopCard(OrderItem order, int number) {
    return GestureDetector(
      onTap: () => _mapController.move(LatLng(order.lat, order.lng), 16),
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: order.isDone
              ? const Color(0xFFF2FBF0)
              : const Color(0xFFF0F5FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: order.isDone
                ? AppColors.green.withValues(alpha: 0.3)
                : AppColors.blue.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: order.isDone ? AppColors.green : AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.id,
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order.isDone)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: AppColors.green,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              order.clientName,
              style: const TextStyle(
                color: AppColors.darkBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              order.district,
              style: TextStyle(
                color: AppColors.lightBlue.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.bottles} бут.',
                  style: TextStyle(
                    color: const Color(0xFF6B8CAE).withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${order.price.toInt()} ₽',
                  style: TextStyle(
                    color: order.isDone ? AppColors.green : AppColors.darkBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MARKERS & BUTTONS ────────────────────────────────────────────────────────

class _StartMarker extends StatelessWidget {
  final bool isGps;
  const _StartMarker({required this.isGps});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isGps ? const Color(0xFF1B5FA8) : const Color(0xFF7B3FE4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          isGps ? Icons.gps_fixed_rounded : Icons.place_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  final int number;
  final bool isDone;
  const _StopMarker({required this.number, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDone ? AppColors.green : AppColors.orange,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _MapBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
