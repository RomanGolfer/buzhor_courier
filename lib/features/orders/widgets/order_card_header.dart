part of 'order_card.dart';

class _OrderCardHeaderRow extends StatelessWidget {
  final OrderItem order;
  final int number;
  final bool isNew;

  const _OrderCardHeaderRow({
    required this.order,
    required this.number,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = OrderTimingService.isOverdue(order);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              _NumberBadge(order: order, number: number),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  order.displayId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (order.isClosed) ...[
                const SizedBox(width: 8),
                Flexible(child: _OrderStatusBadge(order: order)),
              ],
              if (isOverdue) ...[
                const SizedBox(width: 8),
                const Flexible(child: _OrderOverdueBadge()),
              ],
              if (isNew) ...[
                const SizedBox(width: 8),
                const Flexible(child: _OrderNewBadge()),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 104),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${order.price.toInt()} в‚Ѕ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        ),
      ],
    );
  }
}

class _OrderOverdueBadge extends StatelessWidget {
  const _OrderOverdueBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('orderOverdueBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade400.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'РџСЂРѕСЃСЂРѕС‡РµРЅ',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.red.shade500,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OrderNewBadge extends StatelessWidget {
  const _OrderNewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('orderNewBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '\u041d\u043e\u0432\u044b\u0439',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.orange,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
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
        order.isFailed ? 'РќРµ РґРѕСЃС‚Р°РІР»РµРЅ' : 'Р’С‹РїРѕР»РЅРµРЅ',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
