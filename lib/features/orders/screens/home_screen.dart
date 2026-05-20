import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/core/utils/location_utils.dart';
import 'package:buzhor_courier/core/theme/theme_mode_provider.dart';
import 'package:buzhor_courier/features/auth/data/auth_credentials_storage.dart';
import 'package:buzhor_courier/features/auth/screens/login_screen.dart';
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

part 'home_controls.dart';
part 'home_header.dart';
part 'home_map.dart';
part 'home_tabs.dart';
part 'home_order_list.dart';
part 'home_completed.dart';
part 'home_bottom_nav.dart';

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
}
