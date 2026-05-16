part of '../order_detail_screen.dart';

class _OrderItemsCard extends StatelessWidget {
  final OrderItem order;
  const _OrderItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Товары',
            style: TextStyle(
              color: AppColors.darkBlue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Вода питьевая 19л',
                  style: TextStyle(color: AppColors.darkBlue, fontSize: 14),
                ),
              ),
              Text(
                '× ${order.bottles}',
                style: const TextStyle(color: AppColors.grayBlue, fontSize: 14),
              ),
              const SizedBox(width: 12),
              Text(
                '${order.price.toInt()} ₽',
                style: const TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const _RowDivider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Итого',
                style: TextStyle(color: AppColors.grayBlue, fontSize: 14),
              ),
              Text(
                '${order.price.toInt()} ₽',
                style: const TextStyle(color: AppColors.darkBlue, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'К оплате',
                style: TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${order.price.toInt()} ₽',
                style: const TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Comment card ─────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  final String comment;
  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              comment,
              style: TextStyle(
                color: AppColors.orange.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom buttons ───────────────────────────────────────────────────────────
