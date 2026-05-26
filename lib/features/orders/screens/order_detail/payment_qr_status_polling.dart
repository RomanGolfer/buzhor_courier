part of '../order_detail_screen.dart';

extension _PaymentQrStatusPolling on _PaymentQrFullScreenState {
  void _startPaymentPolling() {
    _paymentPollingTimer?.cancel();
    _paymentPollingTimer = Timer.periodic(
      _PaymentQrFullScreenState._paymentPollingInterval,
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
      _setPaymentQrState(() => _isCheckingPayment = true);
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

    _setPaymentQrState(() {
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
