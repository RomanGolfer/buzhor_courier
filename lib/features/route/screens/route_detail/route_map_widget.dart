part of '../route_screen.dart';

class _RouteMapWidget extends StatelessWidget {
  final MapController mapController;
  final List<OrderItem> sortedOrders;
  final LatLng? startPoint;
  final bool isGpsStart;
  final bool isLowDataMode;
  final List<List<LatLng>> routeSegments;
  final double centerLat;
  final double centerLng;
  final void Function(TapPosition, LatLng) onLongPress;

  const _RouteMapWidget({
    required this.mapController,
    required this.sortedOrders,
    required this.startPoint,
    required this.isGpsStart,
    required this.isLowDataMode,
    required this.routeSegments,
    required this.centerLat,
    required this.centerLng,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: 14.5,
        onLongPress: onLongPress,
      ),
      children: [
        if (!isLowDataMode) ...[
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          SimpleAttributionWidget(source: const Text('CartoDB')),
        ],
        if (routeSegments.isNotEmpty)
          PolylineLayer(
            polylines: [
              for (int i = 0; i < routeSegments.length; i++)
                Polyline(
                  points: routeSegments[i],
                  color: (startPoint != null && i == 0)
                      ? AppColors.blue.withValues(alpha: 0.5)
                      : AppColors.orange,
                  strokeWidth: (startPoint != null && i == 0) ? 2.5 : 3.5,
                  pattern: (startPoint != null && i == 0)
                      ? StrokePattern.dashed(segments: const [8, 6])
                      : const StrokePattern.solid(),
                ),
            ],
          ),
        if (startPoint != null)
          MarkerLayer(
            markers: [
              Marker(
                point: startPoint!,
                width: 36,
                height: 36,
                child: _StartMarker(isGps: isGpsStart),
              ),
            ],
          ),
        MarkerLayer(
          markers: List.generate(sortedOrders.length, (i) {
            final o = sortedOrders[i];
            return Marker(
              point: LatLng(o.lat, o.lng),
              width: 32,
              height: 32,
              child: _StopMarker(number: i + 1, isDone: o.isDone),
            );
          }),
        ),
      ],
    );
  }
}

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
