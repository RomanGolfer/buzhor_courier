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

extension _HomeDailyReport on _HomeScreenState {
  Widget _buildDailyReport(OrdersState ordersState) {
    final metrics = _buildDailyReportMetrics(ordersState);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        _ReportFilterButton(
          label: 'Все маршруты',
          onTap: () => ref.read(ordersProvider.notifier).setNavIndex(0),
        ),
        const SizedBox(height: 24),
        _ReportSection(
          key: const Key('dailyReportOrdersSection'),
          title: 'Заказы',
          trailing: _formatInt(metrics.totalOrders),
          rows: [
            _ReportRowData('Доставлено', metrics.deliveredOrders),
            _ReportRowData('Новый, принят, выполняется', metrics.activeOrders),
            _ReportRowData('Не доставлено', metrics.failedOrders),
            _ReportRowData('Отменено', metrics.cancelledOrders),
          ],
        ),
        _ReportSection(
          key: const Key('dailyReportPaymentsSection'),
          title: 'Общая сумма оплат',
          trailing: _formatMoney(metrics.totalPayments),
          rows: [
            _ReportRowData('Наличные', metrics.cashPayments, tappable: true),
            _ReportRowData('Онлайн-оплата', metrics.onlinePayments),
            _ReportRowData('По договору', metrics.contractPayments),
            _ReportRowData('Картой', metrics.cardPayments),
            _ReportRowData('Динамический QR-код', metrics.qrPayments),
          ],
        ),
        _ReportSection(
          key: const Key('dailyReportReturnsSection'),
          title: 'Возвратная тара',
          rows: [
            _ReportRowData('План', metrics.returnPlan),
            _ReportRowData('Возвращено', metrics.returnedTare, tappable: true),
          ],
        ),
        _ReportSection(
          key: const Key('dailyReportWaterSection'),
          title: 'Вода 19л',
          titleTappable: true,
          rows: [
            _ReportRowData('Доставлено', metrics.waterDelivered),
            _ReportRowData('Остаток', metrics.waterBalance),
          ],
        ),
        _ReportSection(
          key: const Key('dailyReportOtherGoodsSection'),
          title: 'Другие товары',
          titleTappable: true,
          rows: [
            _ReportRowData('Доставлено', metrics.otherDelivered),
            _ReportRowData('Остаток', metrics.otherBalance),
          ],
          showDivider: false,
        ),
      ],
    );
  }

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

  String _formatInt(num value) => value.toInt().toString();

  String _formatMoney(num value) => value.toInt().toString();
}

class _ReportFilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReportFilterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          Icons.schedule_rounded,
          color: AppColors.textSecondary(context),
          size: 22,
        ),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary(context),
          side: BorderSide(color: AppColors.dividerColor(context), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final String? trailing;
  final List<_ReportRowData> rows;
  final bool titleTappable;
  final bool showDivider;

  const _ReportSection({
    super.key,
    required this.title,
    required this.rows,
    this.trailing,
    this.titleTappable = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              )
            else if (titleTappable)
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textPrimary(context),
                size: 30,
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final row in rows) _ReportRow(row: row),
        if (showDivider) ...[
          const SizedBox(height: 18),
          Divider(color: AppColors.dividerColor(context), thickness: 1.2),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _ReportRowData {
  final String label;
  final num value;
  final bool tappable;

  const _ReportRowData(this.label, this.value, {this.tappable = false});
}

class _ReportRow extends StatelessWidget {
  final _ReportRowData row;

  const _ReportRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            row.value.toInt().toString(),
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (row.tappable) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary(context),
              size: 26,
            ),
          ],
        ],
      ),
    );
  }
}
