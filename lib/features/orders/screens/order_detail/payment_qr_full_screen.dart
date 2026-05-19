part of '../order_detail_screen.dart';

class _PaymentQrFullScreen extends ConsumerStatefulWidget {
  final OrderItem order;
  final double amount;
  final bool shareOnOpen;

  const _PaymentQrFullScreen({
    required this.order,
    required this.amount,
    this.shareOnOpen = false,
  });

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
    if (widget.shareOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _sharePaymentQr();
        }
      });
    }
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
            final statusHeight = _paymentCheck == null ? 0.0 : 76.0;
            final reservedHeight =
                (isCompact ? 320.0 : 340.0) +
                buttonHeight * 2 +
                buttonSpacing +
                statusHeight;
            final qrSize = math.min(
              (maxWidth - 40).clamp(180.0, 380.0),
              (maxHeight - reservedHeight).clamp(180.0, 380.0),
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
                                  .clamp(180.0, 340.0),
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
                    _PaymentQrFullScreenControls(
                      bottomPadding: isCompact ? 10 : 14,
                      buttonHeight: buttonHeight,
                      buttonSpacing: buttonSpacing,
                      isCheckingPayment: _isCheckingPayment,
                      isSharing: _isSharing,
                      paymentCheck: _paymentCheck,
                      onCheckPayment: () => _checkPayment(),
                      onSharePaymentQr: () => _sharePaymentQr(),
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
                if (_isSharing)
                  _PaymentQrShareCaptureLayer(
                    qrImageKey: _paymentQrImageKey,
                    order: order,
                    amount: widget.amount,
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
          ..showSnackBar(
            const SnackBar(
              content: Text('Не удалось подготовить QR для отправки'),
            ),
          );
      }
      return;
    }

    if (imageFile == null) {
      debugPrint('QR share failed: captured image is null');
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Не удалось подготовить QR для отправки'),
            ),
          );
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
          text:
              'QR для оплаты заказа ${widget.order.id} на сумму ${widget.amount.toInt()} ₽',
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
      final pixelRatio = ui
          .PlatformDispatcher
          .instance
          .views
          .first
          .devicePixelRatio
          .clamp(3.0, 4.0);

      // Wait for the next frame to ensure the RepaintBoundary is fully laid out
      await WidgetsBinding.instance.endOfFrame;
      debugPrint('QR capture: waited for frame');
      if (!mounted) return null;

      final boundaryContext = _paymentQrImageKey.currentContext;
      if (boundaryContext == null) {
        debugPrint('QR capture: boundary context is null');
        return null;
      }
      if (!boundaryContext.mounted) return null;

      final renderObject = boundaryContext.findRenderObject();
      if (renderObject == null) {
        debugPrint('QR capture: render object is null');
        return null;
      }

      if (renderObject is! RenderRepaintBoundary) {
        debugPrint(
          'QR capture: render object is not RenderRepaintBoundary, got ${renderObject.runtimeType}',
        );
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
      final fileName =
          'payment_qr_${widget.order.id.replaceAll('#', '')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      debugPrint('QR capture: writing to ${file.path}');

      await file.writeAsBytes(bytes, flush: true);
      debugPrint(
        'QR capture: file written successfully (${file.lengthSync()} bytes)',
      );
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
        ref
            .read(ordersProvider.notifier)
            .updateOrder(current.copyWith(payment: PaymentType.online));
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
