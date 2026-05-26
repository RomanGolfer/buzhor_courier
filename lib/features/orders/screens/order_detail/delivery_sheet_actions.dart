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

  void _resetWaterScanResult() {
    final updatedMarkingCodes = _copyMarkingCodes(_markingCodes)
      ..remove('water');
    _setDeliverySheetState(() {
      _markingCodes
        ..clear()
        ..addAll(updatedMarkingCodes);
    });
    widget.onMarkingCodesChanged(_copyMarkingCodes(_markingCodes));
    _setScannedItems({});
  }

  void _setClientRating(int value) {
    _setDeliverySheetState(() => _clientRating = value);
  }

  void _setScannedItems(Map<String, int> value) {
    _setDeliverySheetState(() {
      _scannedItems
        ..clear()
        ..addAll(value);
    });
    widget.onScannedItemsChanged(Map.unmodifiable(_scannedItems));
  }

  void _selectQrPaymentAndOpen() {
    _setDeliverySheetState(() => _paymentType = PaymentType.qr);
    widget.onPaymentTypeChanged(PaymentType.qr);
    _showPaymentQrSheet(context, widget.order, amount: widget.totalPrice);
  }
}
