part of 'order_card.dart';

class _CardContent extends StatelessWidget {
  final OrderItem order;
  final VoidCallback? onChatTap;
  final bool showRouteButton;

  const _CardContent({
    required this.order,
    this.onChatTap,
    this.showRouteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.id,
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (order.isClosed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (order.isFailed
                                        ? Colors.red.shade400
                                        : AppColors.green)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.isFailed ? 'Не доставлен' : 'Выполнен',
                            style: TextStyle(
                              color: order.isFailed
                                  ? Colors.red.shade400
                                  : AppColors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
            const SizedBox(width: 4),
            GestureDetector(
              onTap:
                  onChatTap ??
                  () => NavigationService.openMessenger(
                    context,
                    phone: order.phone,
                    message: 'Заказ ${order.id}',
                  ),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.softSurface(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppColors.blue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
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
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${order.clientName} · ${order.bottles} бут.',
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
        ),
        if (order.comment != null) ...[
          const SizedBox(height: 6),
          Row(
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
                  order.comment!,
                  style: TextStyle(
                    color: AppColors.orange.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
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
            if (showRouteButton) ...[
              const Spacer(),
              GestureDetector(
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
            ],
          ],
        ),
      ],
    );
  }
}
