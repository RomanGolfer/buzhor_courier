import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/orders/data/sample_orders.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';

class OrderRepository {
  OrderRepository({List<OrderItem>? initialOrders})
    : _orders = List<OrderItem>.of(initialOrders ?? sampleOrders);

  final List<OrderItem> _orders;

  Future<List<OrderItem>> fetchOrders() async {
    return List.unmodifiable(_orders);
  }

  Future<List<OrderItem>> completeOrder(
    String orderId, {
    required int bottles,
    required int returnedBottles,
    required PaymentType paymentType,
    required Map<String, int> extras,
    String? comment,
  }) async {
    _replaceOrder(
      orderId,
      (order) => order.copyWith(
        isDone: true,
        deliveryState: OrderDeliveryState.delivered,
        deliveredBottles: bottles,
        returnedBottles: returnedBottles,
        confirmedPayment: paymentType,
        extras: Map.unmodifiable(extras),
        deliveryComment: _normalizeOptionalText(comment),
        failureReason: null,
      ),
    );
    return fetchOrders();
  }

  Future<List<OrderItem>> failOrder(
    String orderId, {
    required String reason,
  }) async {
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
    return fetchOrders();
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
  (ref) => OrderRepository(),
);
