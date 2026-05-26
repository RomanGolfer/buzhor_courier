part of 'home_screen.dart';

extension _HomeCompleted on _HomeScreenState {
  Widget _buildCompletedView(OrdersState ordersState) {
    final completedToday = _todayCompletedOrders(ordersState);

    if (completedToday.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: AppColors.green.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Нет выполненных заказов',
              style: TextStyle(
                color: AppColors.textPrimary(context).withValues(alpha: 0.7),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final totalPrice = completedToday.fold<double>(
      0,
      (sum, order) => sum + order.price,
    );
    final totalBottles = completedToday.fold<int>(
      0,
      (sum, order) =>
          sum + (order.isFailed ? 0 : order.deliveredBottles ?? order.bottles),
    );

    return Column(
      children: [
        Container(
          color: AppColors.surface(context),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              _buildStatChip(
                '${completedToday.length}',
                'заказов',
                AppColors.green,
              ),
              const SizedBox(width: 10),
              _buildStatChip('$totalBottles', 'бут.', AppColors.lightBlue),
              const SizedBox(width: 10),
              _buildStatChip('${totalPrice.toInt()} ₽', '', AppColors.orange),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: completedToday.length,
            itemBuilder: (context, i) => OrderCard(
              order: completedToday[i],
              number: i + 1,
              showRouteButton: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: completedToday[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.isEmpty ? value : '$value $label',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
