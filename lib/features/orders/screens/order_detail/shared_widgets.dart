part of '../order_detail_screen.dart';

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: AppColors.orange, size: 20),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final Color color;
  const _PaymentChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _PaymentQrPanel extends StatelessWidget {
  final OrderItem order;

  const _PaymentQrPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    final payload = _paymentQrPayload(order);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _PaymentQrView(payload: payload, size: 120),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QR для оплаты',
                  style: TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${order.price.toInt()} ₽ · заказ ${order.id}',
                  style: const TextStyle(
                    color: AppColors.grayBlue,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _showPaymentQrSheet(context, order),
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  label: const Text('Крупно'),
                ),
              ],
            ),
          ),
        ],
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
        border: Border.all(color: AppColors.divider),
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

void _showPaymentQrSheet(BuildContext context, OrderItem order) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => _PaymentQrFullScreen(order: order)));
}

class _PaymentQrFullScreen extends StatelessWidget {
  final OrderItem order;

  const _PaymentQrFullScreen({required this.order});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final qrSize = (media.size.shortestSide - 48).clamp(280.0, 420.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      media.size.height -
                      media.padding.top -
                      media.padding.bottom -
                      64,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/buzhor_logo_transparent.png',
                      key: const Key('paymentQrLogo'),
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
                    Center(
                      child: _PaymentQrView(
                        payload: _paymentQrPayload(order),
                        size: qrSize.toDouble(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'К оплате',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.grayBlue, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${order.price.toInt()} ₽',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.darkBlue,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.grayBlue,
                tooltip: 'Закрыть',
              ),
            ),
          ],
        ),
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

String _paymentQrPayload(OrderItem order) {
  return Uri(
    scheme: 'https',
    host: 'pay.buzhor.ru',
    path: '/order',
    queryParameters: {
      'order': order.id.replaceAll('#', ''),
      'amount': order.price.toStringAsFixed(2),
    },
  ).toString();
}
