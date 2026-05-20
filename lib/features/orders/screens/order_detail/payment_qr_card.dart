part of '../order_detail_screen.dart';

class _PaymentQrCard extends StatelessWidget {
  final OrderItem order;
  final double amount;

  const _PaymentQrCard({required this.order, required this.amount});

  @override
  Widget build(BuildContext context) {
    final payload = _paymentQrPayload(order, amount: amount);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_rounded,
                color: AppColors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QR для оплаты',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _PaymentChip(label: '${amount.toInt()} ₽', color: AppColors.blue),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PaymentQrOpenTarget(
                order: order,
                amount: amount,
                child: _PaymentQrView(payload: payload, size: 128),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Покажите клиенту для оплаты заказа.',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Заказ ${order.displayId}',
                      style: const TextStyle(
                        color: AppColors.grayBlue,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () => _showPaymentQrSheet(
                            context,
                            order,
                            amount: amount,
                          ),
                          icon: const Icon(
                            Icons.open_in_full_rounded,
                            size: 18,
                          ),
                          label: const Text('Открыть крупно'),
                        ),
                        TextButton.icon(
                          onPressed: () => _showPaymentQrSheet(
                            context,
                            order,
                            amount: amount,
                            shareOnOpen: true,
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Отправить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
