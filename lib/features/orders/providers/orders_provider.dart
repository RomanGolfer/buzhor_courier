import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_worker.dart';
import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/models/time_slot.dart';

part 'orders_slot_grouping.dart';
part 'orders_state.dart';

class OrdersNotifier extends StateNotifier<OrdersState> {
  final OrderRepository _repository;

  OrdersNotifier(this._repository) : super(const OrdersState()) {
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    state = state.copyWith(isLoading: true);
    try {
      final orders = await _repository.fetchOrders();
      _setOrders(orders);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshOrders() async {
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(isLoading: true);
    try {
      await OrderSyncWorker.instance.sync();
      final orders = await _repository.reloadOrders();
      _setOrders(orders);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setNavIndex(int index) {
    state = state.copyWith(navIndex: index, isMapView: false);
  }

  void setMapView(bool value) {
    state = state.copyWith(isMapView: value);
  }

  void toggleLowDataMode() {
    state = state.copyWith(isLowDataMode: !state.isLowDataMode);
  }

  void toggleSlotExpansion(int slotIndex) {
    final updatedSlots = state.timeSlots.asMap().entries.map((entry) {
      if (entry.key != slotIndex) return entry.value;
      return entry.value.copyWith(isExpanded: !entry.value.isExpanded);
    }).toList();
    state = state.copyWith(timeSlots: updatedSlots);
  }

  Future<void> prepareRoute() async {
    if (state.isBuilding) return;
    state = state.copyWith(isBuilding: true, listOpacity: 0.0);
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(isBuilding: false, listOpacity: 1.0);
  }

  Future<void> completeOrder(
    String orderId, {
    required int bottles,
    required int returnedBottles,
    required PaymentType paymentType,
    required Map<String, int> extras,
    required Map<String, int> scannedItems,
    Map<String, List<String>> markingCodes = const {},
    ClientRating? clientRating,
    String? comment,
  }) async {
    final orders = await _repository.completeOrder(
      orderId,
      bottles: bottles,
      returnedBottles: returnedBottles,
      paymentType: paymentType,
      extras: extras,
      scannedItems: scannedItems,
      markingCodes: markingCodes,
      clientRating: clientRating,
      comment: comment,
    );
    _setOrders(orders);
    await OrderSyncWorker.instance.sync();
  }

  Future<void> setMarkingCodes(
    String orderId, {
    required Map<String, List<String>> markingCodes,
  }) async {
    final orders = await _repository.setMarkingCodes(
      orderId,
      markingCodes: markingCodes,
    );
    _setOrders(orders);
    await OrderSyncWorker.instance.sync();
    final refreshed = await _repository.reloadOrders();
    _setOrders(refreshed);
  }

  Future<void> failOrder(String orderId, {required String reason}) async {
    final orders = await _repository.failOrder(orderId, reason: reason);
    _setOrders(orders);
    await OrderSyncWorker.instance.sync();
  }

  Future<void> upsertIncomingOrder(OrderItem order) async {
    _rememberNewOrderIfNeeded(order);
    final orders = await _repository.upsertOrder(order);
    _setOrders(orders);
  }

  Future<void> updateOrder(OrderItem updatedOrder) async {
    _rememberNewOrderIfNeeded(updatedOrder);
    final orders = await _repository.upsertOrder(updatedOrder);
    _setOrders(orders);
  }

  void markOrderSeen(String orderId) {
    if (!state.newOrderIds.contains(orderId)) return;
    state = state.copyWith(newOrderIds: _withoutNewOrderIds({orderId}));
  }

  void markOrdersSeen(Iterable<String> orderIds) {
    final ids = orderIds.toSet();
    if (ids.isEmpty || !state.newOrderIds.any(ids.contains)) return;
    state = state.copyWith(newOrderIds: _withoutNewOrderIds(ids));
  }

  void _setOrders(List<OrderItem> orders) {
    final activeOrders = orders
        .where((order) => !order.isClosed)
        .where(_isCurrentOrFutureDeliveryOrder)
        .toList();
    final completedOrders = orders
        .where((order) => order.isClosed)
        .where(_isClosedOrderInCurrentMoscowDay)
        .toList();
    final activeIds = activeOrders.map((order) => order.id).toSet();
    state = state.copyWith(
      activeOrders: activeOrders,
      completedOrders: completedOrders,
      timeSlots: _buildTimeSlots(activeOrders),
      newOrderIds: state.newOrderIds.intersection(activeIds),
      isLoading: false,
    );
  }

  void _rememberNewOrderIfNeeded(OrderItem order) {
    if (order.isClosed || state.newOrderIds.contains(order.id)) return;
    final alreadyKnown =
        state.activeOrders.any((item) => item.id == order.id) ||
        state.completedOrders.any((item) => item.id == order.id);
    if (alreadyKnown) return;
    state = state.copyWith(newOrderIds: {...state.newOrderIds, order.id});
  }

  Set<String> _withoutNewOrderIds(Set<String> orderIds) {
    return state.newOrderIds.where((id) => !orderIds.contains(id)).toSet();
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((
  ref,
) {
  final repository = ref.read(orderRepositoryProvider);
  return OrdersNotifier(repository);
});
