part of '../order_detail_screen.dart';

extension _OrderDetailActions on _OrderDetailScreenState {
  void _onBottlesChanged(int value) {
    _setOrderDetailState(() => _bottles = value);
    _syncToProvider();
  }

  void _onPaymentTypeChanged(PaymentType value) {
    _setOrderDetailState(() {
      _paymentType = value;
      _pendingPaymentType = value;
    });
    _syncToProvider(
      failureMessage:
          'Не удалось сразу сохранить способ оплаты. Выбор оставлен, попробуйте еще раз.',
    );
  }

  void _onExtrasChanged(Map<String, int> value) {
    _setOrderDetailState(() {
      _extras
        ..clear()
        ..addAll(value);
    });
    _syncToProvider();
  }

  void _onScannedItemsChanged(Map<String, int> value) {
    _setOrderDetailState(() {
      _scannedItems
        ..clear()
        ..addAll(value);
    });
    _syncToProvider();
  }

  void _onMarkingCodesChanged(Map<String, List<String>> value) {
    final markingCounts = _countsFromMarkingCodes(value);
    _setOrderDetailState(() {
      _markingCodes
        ..clear()
        ..addAll(_copyMarkingCodes(value));
      _scannedItems
        ..clear()
        ..addAll(markingCounts);
    });
    _syncToProvider();
  }

  void _syncToProvider({String? failureMessage}) {
    final current = _resolveOrder(ref.read(ordersProvider));
    if (current.isClosed) return;
    final updatedOrder = current.copyWith(
      payment: _paymentType,
      deliveredBottles: _bottles,
      extras: Map.of(_extras),
      scannedItems: Map.of(_scannedItems),
      markingCodes: _copyMarkingCodes(_markingCodes),
    );

    unawaited(
      ref
          .read(ordersProvider.notifier)
          .updateOrder(updatedOrder)
          .then((_) {
            if (!mounted || _pendingPaymentType != updatedOrder.payment) {
              return;
            }
            _setOrderDetailState(() => _pendingPaymentType = null);
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!mounted || failureMessage == null) return;
            _showSyncError(failureMessage);
          }),
    );
  }

  void _showSyncError(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('orderDetailSyncErrorSnackBar'),
          content: Text(message),
        ),
      );
  }

  Future<void> _completeOrder(_DeliveryConfirmation confirmation) {
    return ref
        .read(ordersProvider.notifier)
        .completeOrder(
          widget.order.id,
          bottles: _bottles,
          returnedBottles: confirmation.returnedBottles,
          paymentType: confirmation.paymentType,
          extras: _extras,
          scannedItems: confirmation.scannedItems,
          markingCodes: confirmation.markingCodes,
          clientRating: confirmation.clientRating,
          comment: confirmation.comment,
        );
  }

  Future<void> _failOrder(_FailureConfirmation confirmation) {
    return ref
        .read(ordersProvider.notifier)
        .failOrder(widget.order.id, reason: confirmation.reason);
  }

  void _listenForOrderUpdates() {
    ref.listen<OrdersState>(ordersProvider, (_, next) {
      final updated = next.activeOrders.firstWhere(
        (o) => o.id == widget.order.id,
        orElse: () => widget.order,
      );
      if (updated.isClosed) return;
      final pendingPaymentType = _pendingPaymentType;
      if (pendingPaymentType != null) {
        if (updated.payment == pendingPaymentType &&
            pendingPaymentType == _paymentType) {
          _setOrderDetailState(() => _pendingPaymentType = null);
        }
        return;
      }
      if (updated.payment != _paymentType) {
        _setOrderDetailState(() => _paymentType = updated.payment);
      }
    });
  }
}
