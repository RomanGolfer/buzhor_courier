part of '../order_detail_screen.dart';

extension _DeliverySheetActions on _DeliverySheetState {
  Future<void> _submit() async {
    _setDeliverySheetState(() => _isSubmitting = true);
    await widget.onConfirm(
      _DeliveryConfirmation(
        returnedBottles: _returnedBottles,
        scannedItems: Map.unmodifiable(_scannedItems),
        markingCodes: _copyMarkingCodes(_markingCodes),
        paymentType: _paymentType,
        clientRating: ClientRating(
          rating: _clientRating,
          ratedAt: DateTime.now().toUtc(),
        ),
        comment: _commentController.text,
      ),
    );
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
  }

  void _setWaterMarkingCodes(List<String> codes) {
    final updated = _copyMarkingCodes(_markingCodes);
    if (codes.isEmpty) {
      updated.remove('water');
    } else {
      updated['water'] = List<String>.unmodifiable(codes);
    }
    _setDeliverySheetState(() {
      _markingCodes
        ..clear()
        ..addAll(updated);
      _scannedItems
        ..clear()
        ..addAll(_countsFromMarkingCodes(updated));
    });
    widget.onMarkingCodesChanged(_copyMarkingCodes(_markingCodes));
  }

  Future<void> _resetWaterScanResult() async {
    if (_isResettingMarkingCodes) return;

    final expectedMarkingCodes = _copyMarkingCodes(_markingCodes);
    final updatedMarkingCodes = _copyMarkingCodes(_markingCodes)
      ..remove('water');
    _setDeliverySheetState(() {
      _isResettingMarkingCodes = true;
      _markingCodes
        ..clear()
        ..addAll(updatedMarkingCodes);
      _scannedItems
        ..clear()
        ..addAll(_countsFromMarkingCodes(updatedMarkingCodes));
    });

    try {
      await widget.onMarkingCodesReset(expectedMarkingCodes);
    } finally {
      if (mounted) {
        _setDeliverySheetState(() => _isResettingMarkingCodes = false);
      }
    }
  }

  void _setClientRating(int value) {
    _setDeliverySheetState(() => _clientRating = value);
  }

  void _selectQrPaymentAndOpen() {
    _setDeliverySheetState(() => _paymentType = PaymentType.qr);
    widget.onPaymentTypeChanged(PaymentType.qr);
    _showPaymentQrSheet(context, widget.order, amount: widget.totalPrice);
  }
}
