part of '../route_screen.dart';

class _RouteStopsSheet extends StatelessWidget {
  final List<OrderItem> sortedOrders;
  final void Function(LatLng) onStopTap;

  const _RouteStopsSheet({
    required this.sortedOrders,
    required this.onStopTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final remaining = sortedOrders
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
              itemCount: sortedOrders.length,
              itemBuilder: (_, i) => _RouteStopCard(
                order: sortedOrders[i],
                number: i + 1,
                onTap: () => onStopTap(LatLng(sortedOrders[i].lat, sortedOrders[i].lng)),
              ),
            ),
          ),
          SizedBox(height: bottomPadding + 10),
        ],
      ),
    );
  }
}
