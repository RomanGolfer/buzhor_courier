part of 'home_screen.dart';

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

  String _formatInt(num value) => value.toInt().toString();

  String _formatMoney(num value) => value.toInt().toString();
}
