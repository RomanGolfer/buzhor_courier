part of 'orders_provider.dart';

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
  final Set<String> newOrderIds;

  const OrdersState({
    this.navIndex = 0,
    this.isMapView = false,
    this.isBuilding = false,
    this.isLowDataMode = false,
    this.isLoading = false,
    this.listOpacity = 1.0,
    this.activeOrders = const [],
    this.completedOrders = const [],
    this.timeSlots = const [],
    this.newOrderIds = const {},
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
    Set<String>? newOrderIds,
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
      newOrderIds: newOrderIds ?? this.newOrderIds,
    );
  }
}
