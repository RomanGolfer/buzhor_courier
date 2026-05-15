import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/models/time_slot.dart';
import 'package:buzhor_courier/features/orders/providers/location_provider.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:buzhor_courier/features/orders/widgets/slot_header.dart';
import 'package:buzhor_courier/features/route/screens/route_screen.dart';
import 'package:flutter/material.dart';
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
  late final DraggableScrollableController _mapSheetController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapSheetController = DraggableScrollableController();
    _mapSheetController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).refreshLocation();
    });
  }

  @override
  void dispose() {
    _mapSheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final locationState = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildHeader(locationState),
          if (ordersState.navIndex == 0) _buildTabSwitcher(ordersState),
          Expanded(child: _buildBody(ordersState)),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(ordersState),
    );
  }

  Widget _buildBody(OrdersState ordersState) {
    switch (ordersState.navIndex) {
      case 0:
        if (ordersState.isMapView) {
          return Stack(children: [_buildActiveList(ordersState), _buildMapSheet(ordersState)]);
        }
        return _buildActiveList(ordersState);
      case 1:
        return _buildCompletedView(ordersState);
      default:
        return _buildTabPlaceholder(ordersState.navIndex);
    }
  }

  Widget _buildMapSheet(OrdersState ordersState) {
    const initial = 0.42;
    return DraggableScrollableSheet(
      controller: _mapSheetController,
      initialChildSize: initial,
      minChildSize: 0.18,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.18, 0.42, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _buildMapWidget(ordersState.activeOrders),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapWidget(List<OrderItem> activeOrders) {
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
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        SimpleAttributionWidget(source: const Text('CartoDB')),
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

  Widget _buildHeader(LocationState locationState) {
    return Stack(
      children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.blue.withValues(alpha: 0.6),
                AppColors.blue.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Заказы',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                _buildGpsIndicator(locationState),
              ],
            ),
          ),
        ),
      ],
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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
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
        onTap: () => ref.read(ordersProvider.notifier).setMapView(label == 'Карта'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
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
                  color: active ? AppColors.darkBlue : AppColors.grayBlueLight,
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
            const Text(
              'Все заказы выполнены!',
              style: TextStyle(
                color: AppColors.darkBlue,
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
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: ordersState.timeSlots.length,
        itemBuilder: (context, slotIndex) => _buildTimeSlotGroup(
          ordersState.timeSlots[slotIndex],
          slotIndex,
        ),
      ),
    );
  }

  Widget _buildTimeSlotGroup(TimeSlot slot, int slotIndex) {
    return SlotHeader(
      slot: slot,
      onToggle: () => ref.read(ordersProvider.notifier).toggleSlotExpansion(slotIndex),
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
        ),
      ),
    );
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
                color: AppColors.darkBlue.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final totalPrice = ordersState.completedOrders.fold<double>(0, (sum, order) => sum + order.price);
    final totalBottles = ordersState.completedOrders.fold<int>(0, (sum, order) => sum + order.bottles);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              _buildStatChip('${ordersState.completedOrders.length}', 'заказов', AppColors.green),
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
            itemBuilder: (context, i) => _buildCompletedCard(ordersState.completedOrders[i], i + 1),
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
              color: AppColors.darkBlue.withValues(alpha: 0.5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(OrderItem order, int number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.green),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCardContent(order)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(OrderItem order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.id,
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (order.isDone) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Выполнен',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.clientName,
                    style: const TextStyle(
                      color: AppColors.darkBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${order.price.toInt()} ₽',
                  style: const TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _buildPaymentBadge(order.payment),
              ],
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppColors.blue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 13,
              color: AppColors.grayBlueLight,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                order.address,
                style: const TextStyle(color: AppColors.grayBlue, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                order.district,
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (order.comment != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.orange),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.comment!,
                  style: TextStyle(
                    color: AppColors.orange.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.water_drop_outlined, size: 15, color: AppColors.lightBlue),
            const SizedBox(width: 4),
            Text(
              '${order.bottles} бут.',
              style: const TextStyle(
                color: AppColors.grayBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentBadge(PaymentType type) {
    final IconData icon;
    final Color color;
    final String label;
    switch (type) {
      case PaymentType.card:
        icon = Icons.credit_card_rounded;
        color = AppColors.blue;
        label = 'Карта';
      case PaymentType.cash:
        icon = Icons.payments_outlined;
        color = AppColors.green;
        label = 'Нал';
      case PaymentType.qr:
        icon = Icons.qr_code_rounded;
        color = AppColors.purple;
        label = 'QR';
      case PaymentType.online:
        icon = Icons.smartphone_rounded;
        color = AppColors.orange;
        label = 'Онлайн';
      case PaymentType.contract:
        icon = Icons.description_outlined;
        color = AppColors.grayBlueLight;
        label = 'Договор';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(OrdersState ordersState) {
    const items = [
      (Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'Заказы'),
      (Icons.check_circle_outline_rounded, Icons.check_circle_rounded, 'Выполнено'),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Статистика'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, -2),
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
                              ? AppColors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          active ? iconFill : iconOut,
                          color: active ? AppColors.blue : AppColors.grayBlueLight,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: active ? AppColors.blue : AppColors.grayBlueLight,
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
