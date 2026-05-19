part of '../order_detail_screen.dart';

class _PaymentStatusNotice extends StatelessWidget {
  final PaymentStatusCheck check;

  const _PaymentStatusNotice({required this.check});

  @override
  Widget build(BuildContext context) {
    final color = switch (check.status) {
      PaymentCheckStatus.paid => AppColors.green,
      PaymentCheckStatus.pending => AppColors.orange,
      PaymentCheckStatus.unavailable => AppColors.grayBlue,
    };
    final icon = switch (check.status) {
      PaymentCheckStatus.paid => Icons.check_circle_rounded,
      PaymentCheckStatus.pending => Icons.schedule_rounded,
      PaymentCheckStatus.unavailable => Icons.info_outline_rounded,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              check.message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _copyPaymentOrderId(BuildContext context, OrderItem order) async {
  await Clipboard.setData(ClipboardData(text: order.id));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Номер заказа скопирован')));
}

class _PaymentQrVisibleCard extends StatelessWidget {
  final OrderItem order;
  final double amount;
  final double qrSize;
  final bool compact;

  const _PaymentQrVisibleCard({
    required this.order,
    required this.amount,
    required this.qrSize,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/buzhor_logo_transparent.png',
            key: const Key('paymentQrLogo'),
            height: compact ? 52 : 64,
            fit: BoxFit.contain,
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            'QR для оплаты',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkBlue,
              fontSize: compact ? 21 : 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          GestureDetector(
            onLongPress: () => _copyPaymentOrderId(context, order),
            child: Text(
              'Заказ ${order.id}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grayBlue,
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          _PaymentQrView(
            payload: _paymentQrPayload(order, amount: amount),
            size: qrSize,
          ),
          SizedBox(height: compact ? 10 : 14),
          const Text(
            'К оплате',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grayBlue, fontSize: 16),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            '${amount.toInt()} ₽',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkBlue,
              fontSize: compact ? 30 : 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentQrShareCard extends StatelessWidget {
  final OrderItem order;
  final double amount;
  final double qrSize;

  const _PaymentQrShareCard({
    required this.order,
    required this.amount,
    required this.qrSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      // No border radius — rectangular white canvas prevents transparent
      // corner pixels that messengers render as black.
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/buzhor_logo_transparent.png',
            height: 72,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'QR для оплаты',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkBlue,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onLongPress: () => _copyPaymentOrderId(context, order),
            child: Text(
              'Заказ ${order.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.grayBlue,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _PaymentQrView(
            payload: _paymentQrPayload(order, amount: amount),
            size: qrSize,
          ),
          const SizedBox(height: 28),
          const Text(
            'К оплате',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grayBlue, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toInt()} ₽',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
