part of 'home_screen.dart';

extension _HomeMap on _HomeScreenState {
  static const _fallbackCenter = ll.LatLng(44.8951, 37.3168);

  Widget _buildMapWidget(List<OrderItem> activeOrders, bool isLowDataMode) {
    final mappableOrders = activeOrders
        .where((order) => order.hasCoordinates)
        .toList(growable: false);
    final center = mappableOrders.isNotEmpty
        ? ll.LatLng(mappableOrders[0].lat, mappableOrders[0].lng)
        : _fallbackCenter;
    final hasOrdersWithoutCoordinates =
        activeOrders.isNotEmpty && mappableOrders.length != activeOrders.length;

    return Stack(
      children: [
        FlutterMap(
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
                userAgentPackageName: 'ru.buzhor.courier',
              ),
              SimpleAttributionWidget(source: const Text('CartoDB')),
            ],
            MarkerLayer(
              markers: List.generate(mappableOrders.length, (i) {
                final o = mappableOrders[i];
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
                        '${activeOrders.indexOf(o) + 1}',
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
        ),
        if (hasOrdersWithoutCoordinates)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _MissingCoordinatesBanner(
              count: activeOrders.length - mappableOrders.length,
            ),
          ),
      ],
    );
  }
}

class _MissingCoordinatesBanner extends StatelessWidget {
  final int count;

  const _MissingCoordinatesBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.isDark(context)
            ? const Color(0xFF24282D).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: AppColors.orange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count == 1
                    ? 'У заказа нет координат'
                    : 'У $count заказов нет координат',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
