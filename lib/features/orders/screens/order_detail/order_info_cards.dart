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

class _DeliveryResultCard extends StatelessWidget {
  final OrderItem order;

  const _DeliveryResultCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isFailed = order.isFailed;
    final statusColor = isFailed ? Colors.red.shade400 : AppColors.green;
    final statusLabel = isFailed ? 'Не доставлен' : 'Доставлен';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFailed
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Результат заказа',
                style: TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _PaymentChip(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 14),
          if (isFailed)
            _ResultInfoRow(
              label: 'Причина',
              value: order.failureReason ?? 'Не указана',
            )
          else ...[
            _ResultInfoRow(
              label: 'Доставлено',
              value: '${order.deliveredBottles ?? order.bottles} бут.',
            ),
            const SizedBox(height: 8),
            _ResultInfoRow(
              label: 'Возврат',
              value: '${order.returnedBottles ?? 0} бут.',
            ),
            const SizedBox(height: 8),
            _ResultInfoRow(
              label: 'Оплата',
              value: _paymentLabel(order.confirmedPayment ?? order.payment),
            ),
            if (order.extras.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: order.extras.entries
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key} ×${entry.value}'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.lightBlue.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (order.deliveryComment != null) ...[
              const SizedBox(height: 12),
              _ResultInfoRow(
                label: 'Комментарий',
                value: order.deliveryComment!,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResultInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.grayBlue, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
