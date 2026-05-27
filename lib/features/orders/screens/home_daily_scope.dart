part of 'home_screen.dart';

extension _HomeDailyScope on _HomeScreenState {
  List<OrderItem> _todayCompletedOrders(OrdersState ordersState) {
    return ordersState.completedOrders;
  }
}
