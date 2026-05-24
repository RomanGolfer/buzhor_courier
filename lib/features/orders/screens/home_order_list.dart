part of 'home_screen.dart';

extension _HomeOrderList on _HomeScreenState {
  Widget _buildActiveList(OrdersState ordersState) {
    if (ordersState.activeOrders.isEmpty) {
      return RefreshIndicator(
        color: AppColors.blue,
        backgroundColor: AppColors.surface(context),
        onRefresh: _refreshOrders,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 56,
                        color: AppColors.lightBlue.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Все заказы выполнены!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Потяните вниз или нажмите обновить',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.grayBlue.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _refreshOrders,
                        icon: ordersState.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Обновить'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final timeSlots = ordersState.timeSlots.isNotEmpty
        ? ordersState.timeSlots
        : [TimeSlot(label: '10:00 - 14:00', orders: ordersState.activeOrders)];

    return AnimatedOpacity(
      opacity: ordersState.listOpacity,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: RefreshIndicator(
        color: AppColors.blue,
        backgroundColor: AppColors.surface(context),
        onRefresh: _refreshOrders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              for (int slotIndex = 0; slotIndex < timeSlots.length; slotIndex++)
                _buildTimeSlotGroup(timeSlots[slotIndex], slotIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlotGroup(TimeSlot slot, int slotIndex) {
    return SlotHeader(
      slot: slot,
      newOrderIds: ref.watch(ordersProvider).newOrderIds,
      onToggle: () =>
          ref.read(ordersProvider.notifier).toggleSlotExpansion(slotIndex),
      onBuildRoute: () => _buildRouteForSlot(slot),
      onOrderOpen: (orderId) =>
          ref.read(ordersProvider.notifier).markOrderSeen(orderId),
    );
  }

  Future<void> _buildRouteForSlot(TimeSlot slot) async {
    if (slot.orders.isEmpty) return;
    final routeOrders = slot.orders
        .where((order) => order.hasCoordinates)
        .toList(growable: false);
    if (routeOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У заказов нет координат для маршрута')),
      );
      return;
    }

    ref
        .read(ordersProvider.notifier)
        .markOrdersSeen(slot.orders.map((order) => order.id));
    await ref.read(ordersProvider.notifier).prepareRoute();
    if (!mounted) return;
    if (routeOrders.length != slot.orders.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказы без координат не добавлены в маршрут'),
        ),
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteScreen(
          orders: routeOrders,
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
