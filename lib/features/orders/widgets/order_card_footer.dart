part of 'order_card.dart';

class _OrderCardFooterRow extends StatelessWidget {
  final OrderItem order;
  final bool showRouteButton;

  const _OrderCardFooterRow({
    required this.order,
    required this.showRouteButton,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                size: 15,
                color: AppColors.lightBlue,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${order.bottles} \u0431\u0443\u0442.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!order.isClosed && order.scannedCountFor('water') > 0) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 15,
                  color: AppColors.green,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${order.scannedCountFor('water')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showRouteButton) ...[
          const SizedBox(width: 8),
          _OrderRouteButtonSlot(order: order),
        ],
      ],
    );
  }
}

class _OrderRouteButtonSlot extends StatelessWidget {
  final OrderItem order;

  const _OrderRouteButtonSlot({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = order.hasCoordinates;
    return SizedBox(
      width: _routeActionColumnWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: hasCoordinates
              ? () => NavigationService.openExternalRoute(order.lat, order.lng)
              : null,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: hasCoordinates
                  ? null
                  : AppColors.grayBlue.withValues(alpha: 0.42),
              gradient: hasCoordinates
                  ? const LinearGradient(
                      colors: [AppColors.orange, AppColors.orangeLight],
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasCoordinates
                        ? '\u041c\u0430\u0440\u0448\u0440\u0443\u0442'
                        : '\u041d\u0435\u0442 \u0433\u0435\u043e',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    hasCoordinates
                        ? Icons.arrow_forward_rounded
                        : Icons.location_off_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
