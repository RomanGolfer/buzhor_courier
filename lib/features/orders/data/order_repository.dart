import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/orders/data/sample_orders.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';

class OrderRepository {
  OrderRepository({List<OrderItem>? initialOrders, OrderStorage? storage})
    : _fallbackOrders = List<OrderItem>.of(initialOrders ?? sampleOrders),
      _storage = storage;

  final List<OrderItem> _fallbackOrders;
  final OrderStorage? _storage;
  final List<OrderItem> _orders = [];
  bool _hasLoaded = false;

  Future<List<OrderItem>> fetchOrders() async {
    await _ensureLoaded();
    return List.unmodifiable(_orders);
  }

  Future<List<OrderItem>> completeOrder(
    String orderId, {
    required int bottles,
    required int returnedBottles,
    required PaymentType paymentType,
    required Map<String, int> extras,
    required Map<String, int> scannedItems,
    String? comment,
  }) async {
    await _ensureLoaded();
    _replaceOrder(
      orderId,
      (order) => order.copyWith(
        isDone: true,
        deliveryState: OrderDeliveryState.delivered,
        deliveredBottles: bottles,
        returnedBottles: returnedBottles,
        confirmedPayment: paymentType,
        extras: Map.unmodifiable(extras),
        scannedItems: Map.unmodifiable(scannedItems),
        deliveryComment: _normalizeOptionalText(comment),
        failureReason: null,
      ),
    );
    await _persist();
    return fetchOrders();
  }

  Future<List<OrderItem>> failOrder(
    String orderId, {
    required String reason,
  }) async {
    await _ensureLoaded();
    final normalizedReason = _normalizeOptionalText(reason);
    if (normalizedReason == null) return fetchOrders();

    _replaceOrder(
      orderId,
      (order) => order.copyWith(
        isDone: false,
        deliveryState: OrderDeliveryState.failed,
        failureReason: normalizedReason,
        deliveryComment: null,
      ),
    );
    await _persist();
    return fetchOrders();
  }

  Future<void> _ensureLoaded() async {
    if (_hasLoaded) return;
    final savedOrders = await _storage?.loadOrders();
    _orders
      ..clear()
      ..addAll(savedOrders ?? _fallbackOrders);
    _hasLoaded = true;
  }

  Future<void> _persist() async {
    await _storage?.saveOrders(List.unmodifiable(_orders));
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
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(storage: const SharedPreferencesOrderStorage()),
);
