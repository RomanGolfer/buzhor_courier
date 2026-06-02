part of 'home_screen.dart';

class _DailyReportMetrics {
  final int totalOrders;
  final int deliveredOrders;
  final int activeOrders;
  final int failedOrders;
  final int cancelledOrders;
  final double totalPayments;
  final double cashPayments;
  final double onlinePayments;
  final double contractPayments;
  final double cardPayments;
  final double qrPayments;
  final int returnPlan;
  final int returnedTare;
  final int waterDelivered;
  final int waterBalance;
  final int otherDelivered;
  final int otherBalance;

  const _DailyReportMetrics({
    required this.totalOrders,
    required this.deliveredOrders,
    required this.activeOrders,
    required this.failedOrders,
    required this.cancelledOrders,
    required this.totalPayments,
    required this.cashPayments,
    required this.onlinePayments,
    required this.contractPayments,
    required this.cardPayments,
    required this.qrPayments,
    required this.returnPlan,
    required this.returnedTare,
    required this.waterDelivered,
    required this.waterBalance,
    required this.otherDelivered,
    required this.otherBalance,
  });
}

extension _HomeDailyReportMetrics on _HomeScreenState {
  _DailyReportMetrics _buildDailyReportMetrics(OrdersState state) {
    final completedToday = _todayCompletedOrders(state);
    final allOrders = [...state.activeOrders, ...completedToday];
    final delivered = completedToday.where((order) => !order.isFailed);
    final failed = completedToday.where((order) => order.isFailed);

    double paymentSum(PaymentType type) {
      return delivered.fold<double>(0, (sum, order) {
        final paymentType = order.confirmedPayment ?? order.payment;
        return paymentType == type ? sum + order.price : sum;
      });
    }

    final deliveredBottles = delivered.fold<int>(
      0,
      (sum, order) => sum + (order.deliveredBottles ?? order.bottles),
    );
    final activeBottles = state.activeOrders.fold<int>(
      0,
      (sum, order) => sum + order.bottles,
    );
    final returnedTare = delivered.fold<int>(
      0,
      (sum, order) => sum + (order.returnedBottles ?? 0),
    );
    final otherDelivered = delivered.fold<int>(
      0,
      (sum, order) => sum + _extrasCount(order.extras),
    );
    final otherBalance = state.activeOrders.fold<int>(
      0,
      (sum, order) => sum + _extrasCount(order.extras),
    );

    return _DailyReportMetrics(
      totalOrders: allOrders.length,
      deliveredOrders: delivered.length,
      activeOrders: state.activeOrders.length,
      failedOrders: failed.length,
      cancelledOrders: 0,
      totalPayments: delivered.fold<double>(
        0,
        (sum, order) => sum + order.price,
      ),
      cashPayments: paymentSum(PaymentType.cash),
      onlinePayments: paymentSum(PaymentType.online),
      contractPayments: paymentSum(PaymentType.contract),
      cardPayments: paymentSum(PaymentType.card),
      qrPayments: paymentSum(PaymentType.qr),
      returnPlan: deliveredBottles,
      returnedTare: returnedTare,
      waterDelivered: deliveredBottles,
      waterBalance: activeBottles,
      otherDelivered: otherDelivered,
      otherBalance: otherBalance,
    );
  }

  int _extrasCount(Map<String, int> extras) {
    return extras.values.fold<int>(0, (sum, count) => sum + count);
  }
}
