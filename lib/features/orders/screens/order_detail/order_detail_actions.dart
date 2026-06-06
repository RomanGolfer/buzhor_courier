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
    final current = _resolveOrder(ref.read(ordersProvider));
    if (current.markingCodes.isNotEmpty &&
        !_sameMarkingCodes(current.markingCodes, value)) {
      _setOrderDetailState(() {
        _markingCodes
          ..clear()
          ..addAll(_copyMarkingCodes(current.markingCodes));
        _scannedItems
          ..clear()
          ..addAll(_countsFromMarkingCodes(current.markingCodes));
      });
      _showSyncError(
        'Маркировка уже сохранена на другом устройстве. Новые коды не заменили заказ.',
      );
      return;
    }

    final markingCounts = _countsFromMarkingCodes(value);
    _setOrderDetailState(() {
      _markingCodes
        ..clear()
        ..addAll(_copyMarkingCodes(value));
      _scannedItems
        ..clear()
        ..addAll(markingCounts);
    });
    unawaited(
      ref
          .read(ordersProvider.notifier)
          .setMarkingCodes(
            widget.order.id,
            markingCodes: _copyMarkingCodes(value),
          )
          .catchError((Object error, StackTrace stackTrace) {
            if (!mounted) return;
            _showSyncError(
              'Не удалось сохранить маркировку. Проверьте связь и обновите заказ.',
            );
          }),
    );
  }

  Future<OrderItem?> _refreshOrderBeforeScan() async {
    await ref.read(ordersProvider.notifier).refreshOrders();
    if (!mounted) return null;
    return _resolveOrder(ref.read(ordersProvider));
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
      if (!_sameMarkingCodes(updated.markingCodes, _markingCodes)) {
        final markingCodes = _copyMarkingCodes(updated.markingCodes);
        _setOrderDetailState(() {
          _markingCodes
            ..clear()
            ..addAll(markingCodes);
          _scannedItems
            ..clear()
            ..addAll(_countsFromMarkingCodes(markingCodes));
        });
      }
    });
  }

  bool _sameMarkingCodes(
    Map<String, List<String>> left,
    Map<String, List<String>> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      final other = right[entry.key];
      if (other == null || other.length != entry.value.length) return false;
      for (var i = 0; i < entry.value.length; i += 1) {
        if (entry.value[i] != other[i]) return false;
      }
    }
    return true;
  }
}
