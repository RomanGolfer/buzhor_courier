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

  void _setPaymentQrState(VoidCallback fn) => setState(fn);

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
}
