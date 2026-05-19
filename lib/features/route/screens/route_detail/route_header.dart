part of '../route_screen.dart';

class _RouteHeader extends StatelessWidget {
  final List<OrderItem> sortedOrders;
  final LatLng? startPoint;
  final bool isGpsStart;
  final double centerLat;
  final double centerLng;
  final MapController mapController;
  final VoidCallback onBack;
  final VoidCallback onSearch;

  const _RouteHeader({
    required this.sortedOrders,
    required this.startPoint,
    required this.isGpsStart,
    required this.centerLat,
    required this.centerLng,
    required this.mapController,
    required this.onBack,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            _MapBtn(
              onTap: onBack,
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
                        startPoint == null
                            ? '${sortedOrders.length} остановок'
                            : '${isGpsStart ? 'GPS' : 'Своя точка'} · ${sortedOrders.length} остановок',
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
              onTap: onSearch,
              child: const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.darkBlue,
              ),
            ),
            const SizedBox(width: 8),
            _MapBtn(
              onTap: () =>
                  mapController.move(LatLng(centerLat, centerLng), 14.5),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                size: 20,
                color: AppColors.darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared map overlay widgets ───────────────────────────────────────────────
