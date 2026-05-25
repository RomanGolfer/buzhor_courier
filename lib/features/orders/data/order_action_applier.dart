part of 'order_repository.dart';

extension OrderRepositoryActionApplier on OrderRepository {
  void _applyAction(OrderActionJournalEntry entry) {
    switch (entry.type) {
      case OrderActionType.complete:
        _replaceOrder(entry.orderId, (order) {
          final bottles = entry.payload['bottles'] as int;
          final extras = _intMap(entry.payload['extras']);
          final markingCodes = _stringListMap(entry.payload['markingCodes']);
          final scannedItems = _intMap(entry.payload['scannedItems']);
          final fiscalReceipt = FiscalReceipt.fromJson(
            entry.payload['fiscalReceipt'],
          );
          final clientRating = ClientRating.fromJson(
            entry.payload['clientRating'],
          );
          return order.copyWith(
            isDone: true,
            deliveryState: OrderDeliveryState.delivered,
            price: OrderPricingService.orderTotal(
              bottles: bottles,
              extras: extras,
            ),
            deliveredBottles: bottles,
            returnedBottles: entry.payload['returnedBottles'] as int,
            confirmedPayment: _paymentTypeFromName(
              entry.payload['paymentType'] as String,
            ),
            extras: Map.unmodifiable(extras),
            scannedItems: Map.unmodifiable(
              scannedItems.isEmpty
                  ? _countsFromMarkingCodes(markingCodes)
                  : scannedItems,
            ),
            markingCodes: _unmodifiableStringListMap(markingCodes),
            fiscalReceipt: fiscalReceipt,
            clientRating: clientRating,
            deliveryComment: _normalizeOptionalText(
              entry.payload['comment'] as String?,
            ),
            failureReason: null,
          );
        });
      case OrderActionType.fail:
        _replaceOrder(
          entry.orderId,
          (order) => order.copyWith(
            isDone: false,
            deliveryState: OrderDeliveryState.failed,
            failureReason: _normalizeOptionalText(
              entry.payload['reason'] as String?,
            ),
            deliveryComment: null,
          ),
        );
      case OrderActionType.upsert:
        final order = OrderItem.fromJson(
          entry.payload['order'] as Map<String, dynamic>,
        );
        final index = _orders.indexWhere((item) => item.id == order.id);
        if (index == -1) {
          _orders.add(order);
        } else {
          _orders[index] = order;
        }
    }
  }

  void _replaceOrder(String orderId, OrderItem Function(OrderItem) update) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;
    _orders[index] = update(_orders[index]);
  }

  OrderItem? _findOrder(String orderId) {
    for (final order in _orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  FiscalReceipt _fiscalReceiptForCompletion(
    String orderId,
    PaymentType paymentType,
  ) {
    if (paymentType == PaymentType.contract) {
      return const FiscalReceipt.notRequired();
    }

    final existing = _findOrder(orderId)?.fiscalReceipt;
    if (existing?.status == FiscalReceiptStatus.issued) {
      return existing!;
    }

    final operationId = existing?.operationId ?? _fiscalOperationId(orderId);
    return (existing ?? FiscalReceipt.pending(operationId: operationId))
        .copyWith(
          status: FiscalReceiptStatus.pending,
          operationId: operationId,
          error: null,
        );
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  OrderItem _normalizePrice(OrderItem order) {
    final pricedBottles = order.deliveredBottles ?? order.bottles;
    final currentPrice = OrderPricingService.orderTotal(
      bottles: pricedBottles,
      extras: order.extras,
    );
    if (order.price == currentPrice) return order;
    return order.copyWith(price: currentPrice);
  }
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry(key as String, value as int));
}

Map<String, List<String>> _stringListMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, value) => MapEntry(
      key as String,
      (value as List).map((item) => item.toString()).toList(),
    ),
  );
}

Map<String, int> _countsFromMarkingCodes(
  Map<String, List<String>> markingCodes,
) {
  if (markingCodes.isEmpty) return const {};
  return markingCodes.map((key, codes) => MapEntry(key, codes.length));
}

Map<String, List<String>> _unmodifiableStringListMap(
  Map<String, List<String>> value,
) {
  if (value.isEmpty) return const {};
  return Map.unmodifiable(
    value.map((key, codes) => MapEntry(key, List<String>.unmodifiable(codes))),
  );
}

String _fiscalOperationId(String orderId) {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  return 'fiscal-$orderId-$timestamp';
}

PaymentType _paymentTypeFromName(String name) {
  return PaymentType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => PaymentType.cash,
  );
}
