import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/orders/data/order_action_journal.dart';
import 'package:buzhor_courier/features/orders/data/order_backend_api.dart';
import 'package:buzhor_courier/features/orders/data/sample_orders.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/services/order_pricing_service.dart';

class OrderRepository {
  OrderRepository({
    List<OrderItem>? initialOrders,
    OrderStorage? storage,
    OrderBackendApi? backendApi,
  }) : _fallbackOrders = List<OrderItem>.of(initialOrders ?? sampleOrders),
       _storage = storage,
       _backendApi = backendApi;

  final List<OrderItem> _fallbackOrders;
  final OrderStorage? _storage;
  final OrderBackendApi? _backendApi;
  final List<OrderItem> _orders = [];
  bool _hasLoaded = false;

  Future<List<OrderItem>> fetchOrders() async {
    await _ensureLoaded();
    return List.unmodifiable(_orders);
  }

  Future<List<OrderItem>> reloadOrders() async {
    _hasLoaded = false;
    return fetchOrders();
  }

  Future<List<OrderItem>> completeOrder(
    String orderId, {
    required int bottles,
    required int returnedBottles,
    required PaymentType paymentType,
    required Map<String, int> extras,
    required Map<String, int> scannedItems,
    Map<String, List<String>> markingCodes = const {},
    String? comment,
  }) async {
    await _ensureLoaded();
    await _storage?.appendSyncOperation(
      OrderSyncOperation.complete(
        orderId,
        bottles: bottles,
        returnedBottles: returnedBottles,
        paymentType: paymentType,
        extras: extras,
        scannedItems: scannedItems,
        markingCodes: markingCodes,
        comment: comment,
      ),
    );
    await _commitAction(
      OrderActionJournalEntry.complete(
        orderId,
        bottles: bottles,
        returnedBottles: returnedBottles,
        paymentType: paymentType,
        extras: extras,
        scannedItems: scannedItems,
        markingCodes: markingCodes,
        comment: comment,
      ),
    );
    return fetchOrders();
  }

  Future<List<OrderItem>> failOrder(
    String orderId, {
    required String reason,
  }) async {
    await _ensureLoaded();
    final normalizedReason = _normalizeOptionalText(reason);
    if (normalizedReason == null) return fetchOrders();

    await _storage?.appendSyncOperation(
      OrderSyncOperation.fail(orderId, reason: normalizedReason),
    );
    await _commitAction(
      OrderActionJournalEntry.fail(orderId, reason: normalizedReason),
    );
    return fetchOrders();
  }

  Future<List<OrderItem>> upsertOrder(OrderItem incomingOrder) async {
    await _ensureLoaded();
    await _commitAction(OrderActionJournalEntry.upsert(incomingOrder));
    return fetchOrders();
  }

  Future<void> _ensureLoaded() async {
    if (_hasLoaded) return;
    final currentOrders = List<OrderItem>.of(_orders);
    final backendOrders = await _backendApi?.fetchAssignedOrders();
    final savedOrders = backendOrders == null
        ? await _storage?.loadOrders()
        : null;
    final orders =
        backendOrders ??
        savedOrders ??
        (currentOrders.isEmpty ? _fallbackOrders : currentOrders);
    _orders
      ..clear()
      ..addAll(orders.map(_normalizePrice));
    if (backendOrders != null) await _persist();
    await _replayActionJournal();
    _hasLoaded = true;
  }

  Future<void> _persist() async {
    await _storage?.saveOrders(List.unmodifiable(_orders));
  }

  Future<void> _commitAction(OrderActionJournalEntry entry) async {
    await _storage?.appendActionJournalEntry(entry);
    _applyAction(entry);
    await _persist();
    await _storage?.clearActionJournal();
  }

  Future<void> _replayActionJournal() async {
    final entries = await _storage?.loadActionJournal() ?? const [];
    if (entries.isEmpty) return;

    for (final entry in entries) {
      _applyAction(entry);
    }
    await _persist();
    await _storage?.clearActionJournal();
  }

  void _applyAction(OrderActionJournalEntry entry) {
    switch (entry.type) {
      case OrderActionType.complete:
        _replaceOrder(entry.orderId, (order) {
          final bottles = entry.payload['bottles'] as int;
          final extras = _intMap(entry.payload['extras']);
          final markingCodes = _stringListMap(entry.payload['markingCodes']);
          final scannedItems = _intMap(entry.payload['scannedItems']);
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

PaymentType _paymentTypeFromName(String name) {
  return PaymentType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => PaymentType.cash,
  );
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(
    storage: const SharedPreferencesOrderStorage(),
    backendApi: const SupabaseOrderBackendApi(),
  ),
);
