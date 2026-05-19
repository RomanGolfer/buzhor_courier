part of 'slot_header.dart';

class _SlotHeaderSummary extends StatelessWidget {
  final TimeSlot slot;
  final VoidCallback onToggle;
  final VoidCallback onBuildRoute;

  const _SlotHeaderSummary({
    required this.slot,
    required this.onToggle,
    required this.onBuildRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final totalBottles = slot.orders.fold<int>(
      0,
      (sum, order) => sum + order.bottles,
    );

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.22)
                  : AppColors.blue.withValues(alpha: 0.10),
              blurRadius: isDark ? 16 : 12,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _SlotHeaderText(slot: slot, totalBottles: totalBottles),
            ),
            const SizedBox(width: 8),
            _SlotHeaderActions(
              isExpanded: slot.isExpanded,
              isDark: isDark,
              onBuildRoute: onBuildRoute,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotHeaderText extends StatelessWidget {
  final TimeSlot slot;
  final int totalBottles;

  const _SlotHeaderText({required this.slot, required this.totalBottles});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                slot.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.water_drop_rounded,
              size: 13,
              color: AppColors.lightBlue,
            ),
            const SizedBox(width: 3),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: Text(
                  '$totalBottles',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${slot.orders.length} заказов',
          style: TextStyle(
            color: AppColors.textSecondary(context).withValues(alpha: 0.74),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SlotHeaderActions extends StatelessWidget {
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onBuildRoute;

  const _SlotHeaderActions({
    required this.isExpanded,
    required this.isDark,
    required this.onBuildRoute,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _routeActionColumnWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: onBuildRoute,
            child: Container(
              width: 36,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.softSurface(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.orange.withValues(
                    alpha: isDark ? 0.42 : 0.30,
                  ),
                ),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: AppColors.orange,
                size: 17,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.expand_less_rounded,
              color: AppColors.blue,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
