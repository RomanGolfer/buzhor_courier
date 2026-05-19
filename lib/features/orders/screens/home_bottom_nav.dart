part of 'home_screen.dart';

extension _HomeBottomNav on _HomeScreenState {
  Widget _buildTabPlaceholder(int index) {
    final labels = ['', '', 'Статистика', 'Профиль'];
    final icons = [
      null,
      null,
      Icons.bar_chart_outlined,
      Icons.person_outline_rounded,
    ];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icons[index],
            size: 56,
            color: AppColors.lightBlue.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            labels[index],
            style: TextStyle(
              color: AppColors.textPrimary(context).withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(OrdersState ordersState) {
    final isDark = AppColors.isDark(context);
    const items = [
      (Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'Заказы'),
      (
        Icons.check_circle_outline_rounded,
        Icons.check_circle_rounded,
        'Выполнено',
      ),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Статистика'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17191C) : AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark(context) ? 0.24 : 0.06,
            ),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = ordersState.navIndex == i;
              final (iconOut, iconFill, label) = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => ref.read(ordersProvider.notifier).setNavIndex(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? isDark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : AppColors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          active ? iconFill : iconOut,
                          color: isDark
                              ? Colors.white.withValues(
                                  alpha: active ? 1.0 : 0.66,
                                )
                              : active
                              ? AppColors.blue
                              : AppColors.grayBlueLight,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(
                                  alpha: active ? 1.0 : 0.66,
                                )
                              : active
                              ? AppColors.blue
                              : AppColors.grayBlueLight,
                          fontSize: 11,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
