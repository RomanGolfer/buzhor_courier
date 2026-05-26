part of 'home_screen.dart';

const _moscowUtcOffset = Duration(hours: 3);

extension _HomeDailyScope on _HomeScreenState {
  List<OrderItem> _todayCompletedOrders(OrdersState ordersState) {
    return ordersState.completedOrders
        .where(_isClosedOrderInCurrentMoscowDay)
        .toList();
  }

  bool _isClosedOrderInCurrentMoscowDay(OrderItem order) {
    final closedAt = order.updatedAt ?? order.createdAt;
    if (closedAt == null) return false;
    return _isSameMoscowDate(closedAt, DateTime.now());
  }

  bool _isSameMoscowDate(DateTime left, DateTime right) {
    final moscowLeft = left.toUtc().add(_moscowUtcOffset);
    final moscowRight = right.toUtc().add(_moscowUtcOffset);
    return moscowLeft.year == moscowRight.year &&
        moscowLeft.month == moscowRight.month &&
        moscowLeft.day == moscowRight.day;
  }
}
