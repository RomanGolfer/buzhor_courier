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

class _PaymentQrFullScreen extends ConsumerStatefulWidget {
  final OrderItem order;
  final double amount;

  const _PaymentQrFullScreen({required this.order, required this.amount});

  @override
  ConsumerState<_PaymentQrFullScreen> createState() =>
      _PaymentQrFullScreenState();
}

class _PaymentQrFullScreenState extends ConsumerState<_PaymentQrFullScreen> {
  static const _paymentPollingInterval = Duration(seconds: 7);

  PaymentStatusCheck? _paymentCheck;
  bool _isCheckingPayment = false;
  bool _isPaymentCheckInFlight = false;
  bool _isSharing = false;
  final GlobalKey _paymentQrImageKey = GlobalKey();
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
    final order = widget.order;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            final maxWidth = constraints.maxWidth;
            final isCompact = maxHeight < 760 || maxWidth < 360;
            final buttonHeight = isCompact ? 44.0 : 48.0;
            final buttonSpacing = isCompact ? 8.0 : 12.0;
            final reservedHeight = (isCompact ? 320.0 : 340.0) + buttonHeight * 2 + buttonSpacing;
            final qrSize = math.min(
              (maxWidth - 40).clamp(260.0, 380.0),
              (maxHeight - reservedHeight).clamp(260.0, 380.0),
            );

            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, cardConstraints) {
                            final cardHeight = cardConstraints.maxHeight;
                            final cardCompact = cardHeight < 520 || isCompact;
                            final reducedQrSize = math.min(
                              qrSize,
                              (cardHeight - (cardCompact ? 220.0 : 260.0))
                                  .clamp(260.0, 340.0),
                            );

                            return _PaymentQrVisibleCard(
                              order: order,
                              amount: widget.amount,
                              qrSize: reducedQrSize,
                              compact: cardCompact,
                            );
                          },
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          isCompact ? 10 : 14,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
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
                                  disabledBackgroundColor:
                                      AppColors.grayBlueLight,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: buttonSpacing),
                            SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
                              child: OutlinedButton.icon(
                                onPressed: _isSharing ? null : _sharePaymentQr,
                                icon: Icon(
                                  _isSharing
                                      ? Icons.hourglass_top_rounded
                                      : Icons.share_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  _isSharing ? 'Подготовка...' : 'Отправить QR',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.blue,
                                  side: BorderSide(color: AppColors.blue),
                                  disabledForegroundColor: AppColors.grayBlue,
                                  disabledBackgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            if (_paymentCheck != null) ...[
                              const SizedBox(height: 10),
                              _PaymentStatusNotice(check: _paymentCheck!),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
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
                Offstage(
                  offstage: true,
                  child: SizedBox(
                    width: 360,
                    child: RepaintBoundary(
                      key: _paymentQrImageKey,
                      child: _PaymentQrShareCard(
                        order: order,
                        amount: widget.amount,
                        qrSize: 300,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sharePaymentQr() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final imageFile = await _capturePaymentQrImage();
      if (!mounted || imageFile == null) return;

      await SharePlus.instance.share(
        ShareParams(
          text: 'QR для оплаты заказа ${widget.order.id} на сумму ${widget.amount.toInt()} ₽',
          files: [XFile(imageFile.path)],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Не удалось подготовить QR для отправки'),
          ));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<File?> _capturePaymentQrImage() async {
    final renderObject = _paymentQrImageKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final pixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(3.0, 4.0);
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/payment_qr_${widget.order.id.replaceAll('#', '')}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
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
      final state = ref.read(ordersProvider);
      final current = state.activeOrders.firstWhere(
        (o) => o.id == widget.order.id,
        orElse: () => widget.order,
      );
      if (!current.isClosed) {
        ref.read(ordersProvider.notifier).updateOrder(
          current.copyWith(payment: PaymentType.online),
        );
      }
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
        horizontal: compact ? 14 : 18,
        vertical: compact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.dividerColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/buzhor_logo_transparent.png',
            height: compact ? 60 : 72,
            fit: BoxFit.contain,
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            'QR для оплаты',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkBlue,
              fontSize: compact ? 24 : 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          GestureDetector(
            onLongPress: () => _copyPaymentOrderId(context, order),
            child: Text(
              'Заказ ${order.id}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grayBlue,
                fontSize: compact ? 18 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: compact ? 16 : 20),
          _PaymentQrView(
            payload: _paymentQrPayload(order, amount: amount),
            size: qrSize,
          ),
          SizedBox(height: compact ? 14 : 18),
          const Text(
            'К оплате',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grayBlue, fontSize: 16),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            '${amount.toInt()} ₽',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkBlue,
              fontSize: compact ? 34 : 40,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.dividerColor(context)),
      ),
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
