import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/core/theme/theme_mode_provider.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/models/time_slot.dart';
import 'package:buzhor_courier/features/orders/providers/location_provider.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:buzhor_courier/features/orders/screens/order_detail_screen.dart';
import 'package:buzhor_courier/features/orders/widgets/order_card.dart';
import 'package:buzhor_courier/features/orders/widgets/slot_header.dart';
import 'package:buzhor_courier/features/route/screens/route_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).refreshLocation();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final locationState = ref.watch(locationProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildHeader(locationState, ordersState),
            if (ordersState.navIndex == 0) _buildTabSwitcher(ordersState),
            Expanded(child: _buildBody(ordersState)),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(ordersState),
      ),
    );
  }

  Widget _buildBody(OrdersState ordersState) {
    switch (ordersState.navIndex) {
      case 0:
        if (ordersState.isMapView) {
          return _buildMapWidget(
            ordersState.activeOrders,
            ordersState.isLowDataMode,
          );
        }
        return _buildActiveList(ordersState);
      case 1:
        return _buildCompletedView(ordersState);
      default:
        return _buildTabPlaceholder(ordersState.navIndex);
    }
  }

  Widget _buildMapWidget(List<OrderItem> activeOrders, bool isLowDataMode) {
    final center = activeOrders.isNotEmpty
        ? ll.LatLng(activeOrders[0].lat, activeOrders[0].lng)
        : ll.LatLng(44.8951, 37.3168);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        if (!isLowDataMode) ...[
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          SimpleAttributionWidget(source: const Text('CartoDB')),
        ],
        MarkerLayer(
          markers: List.generate(activeOrders.length, (i) {
            final o = activeOrders[i];
            return Marker(
              point: ll.LatLng(o.lat, o.lng),
              width: 44,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHeader(LocationState locationState, OrdersState ordersState) {
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF22262B), Color(0xFF151719)]
              : const [Color(0xFF063B6F), AppColors.blue],
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

    return GestureDetector(
      onTap: () => ref.read(locationProvider.notifier).refreshLocation(),
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
            'GPS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildCompletedView(OrdersState ordersState) {
    if (ordersState.completedOrders.isEmpty) {
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

    final totalPrice = ordersState.completedOrders.fold<double>(
      0,
      (sum, order) => sum + order.price,
    );
    final totalBottles = ordersState.completedOrders.fold<int>(
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
                '${ordersState.completedOrders.length}',
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
            itemCount: ordersState.completedOrders.length,
            itemBuilder: (context, i) => OrderCard(
              order: ordersState.completedOrders[i],
              number: i + 1,
              showRouteButton: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      OrderDetailScreen(order: ordersState.completedOrders[i]),
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

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeToggle({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: Colors.white,
        size: 18,
      ),
      tooltip: isDark ? 'Темная тема' : 'Светлая тема',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        fixedSize: const Size(34, 34),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _LowDataToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _LowDataToggle({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.signal_cellular_alt_1_bar : Icons.speed_rounded,
              color: enabled ? AppColors.liveGreen : Colors.white,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              enabled ? '2G' : '2G',
              style: TextStyle(
                color: enabled ? AppColors.liveGreen : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
