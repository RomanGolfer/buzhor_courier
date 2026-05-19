part of 'home_screen.dart';

extension _HomeMap on _HomeScreenState {
  Widget _buildMapWidget(List<OrderItem> activeOrders, bool isLowDataMode) {
    final center = activeOrders.isNotEmpty
        ? ll.LatLng(activeOrders[0].lat, activeOrders[0].lng)
        : ll.LatLng(44.8951, 37.3168);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
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
        MarkerLayer(
          markers: List.generate(activeOrders.length, (i) {
            final o = activeOrders[i];
            return Marker(
              point: ll.LatLng(o.lat, o.lng),
              width: 44,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
