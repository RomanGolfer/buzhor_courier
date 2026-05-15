import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/core/services/navigation_service.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  final OrderItem order;
  final int number;
  final VoidCallback? onChatTap;
  final bool showRouteButton;

  const OrderCard({
    super.key,
    required this.order,
    required this.number,
    this.onChatTap,
    this.showRouteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = order.isDone ? AppColors.green : AppColors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: borderColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NumberBadge(number: number, isDone: order.isDone),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CardContent(
                        order: order,
                        onChatTap: onChatTap,
                        showRouteButton: showRouteButton,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  final bool isDone;

  const _NumberBadge({required this.number, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final color = isDone ? AppColors.green : AppColors.orange;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

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
                      if (order.isDone) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Выполнен',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.clientName,
                    style: const TextStyle(
                      color: AppColors.darkBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
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
                  style: const TextStyle(
                    color: AppColors.darkBlue,
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
              onTap: onChatTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
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
              size: 13,
              color: AppColors.grayBlueLight,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                order.address,
                style: const TextStyle(color: AppColors.grayBlue, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                order.district,
                style: const TextStyle(
                  color: AppColors.blue,
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
              style: const TextStyle(
                color: AppColors.grayBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showRouteButton) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => NavigationService.openExternalRoute(order.lat, order.lng),
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

class _PaymentBadge extends StatelessWidget {
  final PaymentType type;
  const _PaymentBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String label;
    switch (type) {
      case PaymentType.card:
        icon = Icons.credit_card_rounded;
        color = AppColors.blue;
        label = 'Карта';
      case PaymentType.cash:
        icon = Icons.payments_outlined;
        color = AppColors.green;
        label = 'Нал';
      case PaymentType.qr:
        icon = Icons.qr_code_rounded;
        color = AppColors.purple;
        label = 'QR';
      case PaymentType.online:
        icon = Icons.smartphone_rounded;
        color = AppColors.orange;
        label = 'Онлайн';
      case PaymentType.contract:
        icon = Icons.description_outlined;
        color = AppColors.grayBlueLight;
        label = 'Договор';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
