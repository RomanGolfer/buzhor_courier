part of '../order_detail_screen.dart';

class _PaymentQrPanel extends StatelessWidget {
  final OrderItem order;
  final double? amount;

  const _PaymentQrPanel({required this.order, this.amount});

  @override
  Widget build(BuildContext context) {
    final paymentAmount = amount ?? order.price;
    final payload = _paymentQrPayload(order, amount: paymentAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerColor(context)),
      ),
      child: Row(
        children: [
          _PaymentQrOpenTarget(
            order: order,
            amount: paymentAmount,
            child: _PaymentQrView(payload: payload, size: 120),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QR для оплаты',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${paymentAmount.toInt()} ₽ · заказ ${order.id}',
                  style: const TextStyle(
                    color: AppColors.grayBlue,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showPaymentQrSheet(
                        context,
                        order,
                        amount: paymentAmount,
                      ),
                      icon: const Icon(Icons.open_in_full_rounded, size: 18),
                      label: const Text('Крупно'),
                    ),
                    TextButton.icon(
                      onPressed: () => _showPaymentQrSheet(
                        context,
                        order,
                        amount: paymentAmount,
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
    );
  }
}

class _PaymentQrOpenTarget extends StatelessWidget {
  final OrderItem order;
  final double amount;
  final Widget child;

  const _PaymentQrOpenTarget({
    required this.order,
    required this.amount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Открыть QR крупно',
      child: GestureDetector(
        key: const Key('compactPaymentQrTapTarget'),
        onTap: () => _showPaymentQrSheet(context, order, amount: amount),
        child: child,
      ),
    );
  }
}

class _PaymentQrView extends StatelessWidget {
  final String payload;
  final double size;

  const _PaymentQrView({required this.payload, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerColor(context)),
      ),
      child: QrImageView(
        data: payload,
        version: QrVersions.auto,
        backgroundColor: Colors.white,
        gapless: false,
      ),
    );
  }
}

void _showPaymentQrSheet(
  BuildContext context,
  OrderItem order, {
  double? amount,
  bool shareOnOpen = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _PaymentQrFullScreen(
        order: order,
        amount: amount ?? order.price,
        shareOnOpen: shareOnOpen,
      ),
    ),
  );
}
