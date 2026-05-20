part of 'order_card.dart';

class _OrderCardHeaderRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardHeaderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                order.displayId,
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (order.isClosed) ...[
                const SizedBox(width: 8),
                _OrderStatusBadge(order: order),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${order.price.toInt()} ₽',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            _PaymentBadge(type: order.payment),
          ],
        ),
      ],
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final OrderItem order;

  const _OrderStatusBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = order.isFailed ? Colors.red.shade400 : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        order.isFailed ? 'Не доставлен' : 'Выполнен',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OrderCardAddressRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardAddressRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: AppColors.grayBlueLight,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            order.address,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OrderCardClientRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardClientRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            order.clientName,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.isDark(context)
                ? AppColors.softSurface(context)
                : const Color(0xFFD6E8F8),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            order.district,
            style: TextStyle(
              color: AppColors.isDark(context)
                  ? AppColors.grayBlueLight
                  : AppColors.blue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderCardCommentRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardCommentRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final comment = order.comment;
    if (comment == null || comment.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: AppColors.orange,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              comment,
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        const Icon(
          Icons.water_drop_outlined,
          size: 15,
          color: AppColors.lightBlue,
        ),
        const SizedBox(width: 4),
        Text(
          '${order.bottles} бут.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!order.isClosed && order.scannedItems.isNotEmpty) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.qr_code_scanner_rounded,
            size: 15,
            color: AppColors.green,
          ),
          const SizedBox(width: 3),
          Text(
            '${order.scannedItems['water'] ?? 0}',
            style: const TextStyle(
              color: AppColors.green,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (showRouteButton) ...[
          const Spacer(),
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
    return SizedBox(
      width: _routeActionColumnWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () =>
              NavigationService.openExternalRoute(order.lat, order.lng),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.orange, AppColors.orangeLight],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Маршрут',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 3),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
