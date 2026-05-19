part of 'home_screen.dart';

extension _HomeHeader on _HomeScreenState {
  Widget _buildHeader(LocationState locationState, OrdersState ordersState) {
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : null,
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF063B6F), AppColors.blue],
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Заказы',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              _LowDataToggle(
                enabled: ordersState.isLowDataMode,
                onTap: () =>
                    ref.read(ordersProvider.notifier).toggleLowDataMode(),
              ),
              const SizedBox(width: 10),
              _ThemeToggle(
                isDark: ref.watch(themeModeProvider) == ThemeMode.dark,
                onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              ),
              const SizedBox(width: 10),
              _buildGpsIndicator(locationState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsIndicator(LocationState locationState) {
    if (locationState.isLocating) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              color: Colors.white.withValues(alpha: 0.8),
              strokeWidth: 1.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'GPS...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    if (locationState.position != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.gps_fixed_rounded, color: AppColors.liveGreen, size: 13),
          SizedBox(width: 4),
          Text(
            'GPS',
            style: TextStyle(
              color: AppColors.liveGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final isDeniedForever =
        locationState.error == GpsError.permissionDeniedForever;
    final isServiceDisabled = locationState.error == GpsError.serviceDisabled;

    return GestureDetector(
      onTap: () async {
        if (isDeniedForever) {
          await LocationUtils.openSettings();
        } else if (isServiceDisabled) {
          await LocationUtils.openLocationSettings();
        } else {
          ref.read(locationProvider.notifier).refreshLocation();
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.gps_off_rounded,
            color: Colors.white.withValues(alpha: 0.55),
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            isDeniedForever
                ? 'Нет доступа'
                : isServiceDisabled
                ? 'Выкл'
                : 'GPS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
