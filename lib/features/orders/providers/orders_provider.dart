import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/models/time_slot.dart';

class OrdersState {
  final int navIndex;
  final bool isMapView;
  final bool isBuilding;
  final bool isLowDataMode;
  final bool isLoading;
  final double listOpacity;
  final List<OrderItem> activeOrders;
  final List<OrderItem> completedOrders;
  final List<TimeSlot> timeSlots;

  const OrdersState({
    this.navIndex = 0,
    this.isMapView = false,
    this.isBuilding = false,
    this.isLowDataMode = false,
    this.isLoading = true,
    this.listOpacity = 1.0,
    this.activeOrders = const [],
    this.completedOrders = const [],
    this.timeSlots = const [],
  });

  OrdersState copyWith({
    int? navIndex,
    bool? isMapView,
    bool? isBuilding,
    bool? isLowDataMode,
    bool? isLoading,
    double? listOpacity,
    List<OrderItem>? activeOrders,
    List<OrderItem>? completedOrders,
    List<TimeSlot>? timeSlots,
  }) {
    return OrdersState(
      navIndex: navIndex ?? this.navIndex,
      isMapView: isMapView ?? this.isMapView,
      isBuilding: isBuilding ?? this.isBuilding,
      isLowDataMode: isLowDataMode ?? this.isLowDataMode,
      isLoading: isLoading ?? this.isLoading,
      listOpacity: listOpacity ?? this.listOpacity,
      activeOrders: activeOrders ?? this.activeOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      timeSlots: timeSlots ?? this.timeSlots,
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  final OrderRepository _repository;

  OrdersNotifier(this._repository) : super(const OrdersState()) {
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await _repository.fetchOrders();
    _setOrders(orders);
  }

  Future<void> refreshOrders() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _loadOrders();
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
    String? comment,
  }) async {
    final orders = await _repository.completeOrder(
      orderId,
      bottles: bottles,
      returnedBottles: returnedBottles,
      paymentType: paymentType,
      extras: extras,
      scannedItems: scannedItems,
      comment: comment,
    );
    _setOrders(orders);
  }

  Future<void> failOrder(String orderId, {required String reason}) async {
    final orders = await _repository.failOrder(orderId, reason: reason);
    _setOrders(orders);
  }

  Future<void> upsertIncomingOrder(OrderItem order) async {
    final orders = await _repository.upsertOrder(order);
    _setOrders(orders);
  }

  void _setOrders(List<OrderItem> orders) {
    final activeOrders = orders.where((order) => !order.isClosed).toList();
    final completedOrders = orders.where((order) => order.isClosed).toList();
    state = state.copyWith(
      activeOrders: activeOrders,
      completedOrders: completedOrders,
      timeSlots: _buildTimeSlots(activeOrders),
      isLoading: false,
    );
  }

  List<TimeSlot> _buildTimeSlots(List<OrderItem> activeOrders) {
    final firstSlot = activeOrders.sublist(0, min(activeOrders.length, 4));
    final secondSlot = activeOrders.sublist(min(activeOrders.length, 4));
    final slots = <TimeSlot>[];

    if (firstSlot.isNotEmpty) {
      slots.add(TimeSlot(label: '10:00 - 14:00', orders: firstSlot));
    }
    if (secondSlot.isNotEmpty) {
      slots.add(TimeSlot(label: '14:00 - 18:00', orders: secondSlot));
    }

    return slots;
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((
  ref,
) {
  final repository = ref.read(orderRepositoryProvider);
  return OrdersNotifier(repository);
});
