part of 'home_screen.dart';

extension _HomeTabs on _HomeScreenState {
  Widget _buildTabSwitcher(OrdersState ordersState) {
    return Container(
      color: AppColors.surface(context),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.softSurface(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTab('Список', Icons.list_rounded, !ordersState.isMapView),
            _buildTab('Карта', Icons.map_outlined, ordersState.isMapView),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            ref.read(ordersProvider.notifier).setMapView(label == 'Карта'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? AppColors.surface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.blue : AppColors.grayBlueLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? AppColors.textPrimary(context)
                      : AppColors.textSecondary(context),
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
