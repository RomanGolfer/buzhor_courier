// ignore_for_file: use_build_context_synchronously
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

  // Payment status check is temporarily disabled in the UI.
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
                                onPressed: _isCheckingPayment ? null : _onCheckPaymentPressed,
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
                            // Payment status panel intentionally hidden until feature is implemented.
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
                // Positioned off-screen (not Offstage) so Flutter still paints
                // the widget — required for RepaintBoundary.toImage() to work.
                // Outer ColoredBox ensures the full PNG canvas is solid white
                // with no transparent pixels (prevents black corners in messengers).
                Positioned(
                  left: -9999,
                  top: -9999,
                  child: RepaintBoundary(
                    key: _paymentQrImageKey,
                    child: ColoredBox(
                      color: Colors.white,
                      child: SizedBox(
                        width: 360,
                        child: _PaymentQrShareCard(
                          order: order,
                          amount: widget.amount,
                          qrSize: 300,
                        ),
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

    final File? imageFile;
    try {
      imageFile = await _capturePaymentQrImage();
    } catch (e, st) {
      debugPrint('QR capture error: $e\n$st');
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Не удалось подготовить QR для отправки'),
          ));
      }
      return;
    }

    if (imageFile == null) {
      debugPrint('QR share failed: captured image is null');
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Не удалось подготовить QR для отправки'),
          ));
      }
      return;
    }

    debugPrint('QR share: image ready at ${imageFile.path}');

    // Navigate back to the orders list before opening the share sheet so that
    // when the courier returns from the messenger, they land on HomeScreen.
    // HomeScreen is route.isFirst because LoginScreen was pushReplacement'd.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Brief pause for the pop animation to settle before the share sheet opens.
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'QR для оплаты заказа ${widget.order.id} на сумму ${widget.amount.toInt()} ₽',
          files: [XFile(imageFile.path)],
        ),
      );
      debugPrint('QR share: completed successfully');
    } catch (e, st) {
      debugPrint('QR share error after navigation: $e\n$st');
      // Widget is already disposed at this point; no UI feedback needed.
    }
  }

  Future<File?> _capturePaymentQrImage() async {
    try {
      // Capture pixel ratio before async operations (avoid using BuildContext across await)
      final pixelRatio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio.clamp(3.0, 4.0);
      
      // Wait for the next frame to ensure the RepaintBoundary is fully laid out
      await WidgetsBinding.instance.endOfFrame;
      debugPrint('QR capture: waited for frame');

      final boundaryContext = _paymentQrImageKey.currentContext;
      if (boundaryContext == null) {
        debugPrint('QR capture: boundary context is null');
        return null;
      }

      final renderObject = boundaryContext.findRenderObject();
      if (renderObject == null) {
        debugPrint('QR capture: render object is null');
        return null;
      }

      if (renderObject is! RenderRepaintBoundary) {
        debugPrint('QR capture: render object is not RenderRepaintBoundary, got ${renderObject.runtimeType}');
        return null;
      }

      debugPrint('QR capture: capturing image with pixelRatio $pixelRatio');
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      debugPrint('QR capture: image captured');

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('QR capture: byteData is null after toByteData');
        return null;
      }

      final bytes = byteData.buffer.asUint8List();
      debugPrint('QR capture: converted to bytes (${bytes.length} bytes)');

      final tempDir = await getTemporaryDirectory();
      final fileName = 'payment_qr_${widget.order.id.replaceAll('#', '')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      debugPrint('QR capture: writing to ${file.path}');

      await file.writeAsBytes(bytes, flush: true);
      debugPrint('QR capture: file written successfully (${file.lengthSync()} bytes)');
      return file;
    } catch (e, st) {
      debugPrint('QR capture error: $e\n$st');
      return null;
    }
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

    setState(() => _isCheckingPayment = false);

    if (showFeedback) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  void _onCheckPaymentPressed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Проверка оплаты пока недоступна'),
      ));
  }
}

// Payment status notice widget removed while feature is disabled.

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
