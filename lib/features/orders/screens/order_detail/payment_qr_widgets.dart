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
                TextButton.icon(
                  onPressed: () => _showPaymentQrSheet(
                    context,
                    order,
                    amount: paymentAmount,
                  ),
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
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          _PaymentQrFullScreen(order: order, amount: amount ?? order.price),
    ),
  );
}

class _PaymentQrFullScreen extends StatefulWidget {
  final OrderItem order;
  final double amount;

  const _PaymentQrFullScreen({required this.order, required this.amount});

  @override
  State<_PaymentQrFullScreen> createState() => _PaymentQrFullScreenState();
}

class _PaymentQrFullScreenState extends State<_PaymentQrFullScreen> {
  static const _paymentPollingInterval = Duration(seconds: 7);

  PaymentStatusCheck? _paymentCheck;
  bool _isCheckingPayment = false;
  bool _isPaymentCheckInFlight = false;
  Timer? _paymentPollingTimer;

  @override
  void initState() {
    super.initState();
    _startPaymentPolling();
  }

  @override
  void dispose() {
    _paymentPollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final qrSize = (media.size.shortestSide - 48).clamp(280.0, 420.0);
    final order = widget.order;

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
                        payload: _paymentQrPayload(
                          order,
                          amount: widget.amount,
                        ),
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
                      '${widget.amount.toInt()} ₽',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.darkBlue,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isCheckingPayment ? null : _checkPayment,
                        icon: Icon(
                          _isCheckingPayment
                              ? Icons.hourglass_top_rounded
                              : Icons.verified_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          _isCheckingPayment
                              ? 'Проверяем...'
                              : 'Проверить оплату',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          disabledBackgroundColor: AppColors.grayBlueLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    if (_paymentCheck != null) ...[
                      const SizedBox(height: 12),
                      _PaymentStatusNotice(check: _paymentCheck!),
                    ],
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

  void _startPaymentPolling() {
    _paymentPollingTimer?.cancel();
    _paymentPollingTimer = Timer.periodic(
      _paymentPollingInterval,
      (_) => _checkPayment(showFeedback: false, showLoading: false),
    );
  }

  Future<void> _checkPayment({
    bool showFeedback = true,
    bool showLoading = true,
  }) async {
    if (_isPaymentCheckInFlight) return;
    _isPaymentCheckInFlight = true;
    if (showLoading) {
      setState(() => _isCheckingPayment = true);
    }

    final result = await PaymentStatusService.checkPayment(widget.order);
    _isPaymentCheckInFlight = false;
    if (!mounted) return;

    if (result.status == PaymentCheckStatus.paid) {
      _paymentPollingTimer?.cancel();
    }

    setState(() {
      _paymentCheck = result;
      _isCheckingPayment = false;
    });

    if (showFeedback) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.message)));
    }
  }
}

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

String _paymentQrPayload(OrderItem order, {double? amount}) {
  final paymentAmount = amount ?? order.price;
  return Uri(
    scheme: 'https',
    host: 'pay.buzhor.ru',
    path: '/order',
    queryParameters: {
      'order': order.id.replaceAll('#', ''),
      'amount': paymentAmount.toStringAsFixed(2),
    },
  ).toString();
}
