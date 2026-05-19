part of 'home_screen.dart';

extension _HomeOrderList on _HomeScreenState {
  Widget _buildActiveList(OrdersState ordersState) {
    if (ordersState.activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 56,
              color: AppColors.lightBlue.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Все заказы выполнены!',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Статистика работы',
              style: TextStyle(
                color: AppColors.grayBlue.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedOpacity(
      opacity: ordersState.listOpacity,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: RefreshIndicator(
        color: AppColors.blue,
        backgroundColor: AppColors.surface(context),
        onRefresh: _refreshOrders,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: ordersState.timeSlots.length,
          itemBuilder: (context, slotIndex) =>
              _buildTimeSlotGroup(ordersState.timeSlots[slotIndex], slotIndex),
        ),
      ),
    );
  }

  Widget _buildTimeSlotGroup(TimeSlot slot, int slotIndex) {
    return SlotHeader(
      slot: slot,
      onToggle: () =>
          ref.read(ordersProvider.notifier).toggleSlotExpansion(slotIndex),
      onBuildRoute: () => _buildRouteForSlot(slot),
    );
  }

  Future<void> _buildRouteForSlot(TimeSlot slot) async {
    if (slot.orders.isEmpty) return;

    await ref.read(ordersProvider.notifier).prepareRoute();
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteScreen(
          orders: List.from(slot.orders),
          startLat: ref.read(locationProvider).position?.latitude,
          startLng: ref.read(locationProvider).position?.longitude,
          initialLowDataMode: ref.read(ordersProvider).isLowDataMode,
        ),
      ),
    );
  }

  Future<void> _refreshOrders() async {
    await ref.read(ordersProvider.notifier).refreshOrders();
  }
}
