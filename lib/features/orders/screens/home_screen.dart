import 'package:buzhor_courier/features/route/screens/route_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/models/time_slot.dart';

const _blue = Color(0xFF1B5FA8);
const _darkBlue = Color(0xFF0D3D6E);
const _lightBlue = Color(0xFF5BB8F5);
const _green = Color(0xFF4A8C2A);
const _orange = Color(0xFFE8720C);
const _bg = Color(0xFFF0F5FB);
const _liveGreen = Color(0xFF6FCF3A);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  bool _isMapView = false;
  bool _isBuilding = false;
  double _listOpacity = 1.0;

  List<OrderItem> _activeOrders = [];
  List<OrderItem> _completedOrders = [];
  List<TimeSlot> _timeSlots = [];
  // Map + draggable sheet controllers
  late final MapController _mapController;
  late final DraggableScrollableController _mapSheetController;

  Position? _currentPosition;
  bool _isLocating = false;

  static const _allOrders = [
    OrderItem(
      id: '#4821',
      clientName: '╨Ш╨▓╨░╨╜╨╛╨▓╨░ ╨Ь╨░╤А╨╕╨╜╨░',
      address: '╤Г╨╗. ╨Ъ╤А╤Л╨╝╤Б╨║╨░╤П, 45, ╨║╨▓. 12',
      district: '╨ж╨╡╨╜╤В╤А',
      price: 840,
      payment: PaymentType.card,
      bottles: 3,
      lat: 44.8951,
      lng: 37.3168,
      comment:
          '╨Ф╨╛╨╝╨╛╤Д╨╛╨╜ ╨╜╨╡ ╤А╨░╨▒╨╛╤В╨░╨╡╤В, ╨╖╨▓╨╛╨╜╨╕╤В╤М ╨┐╨╛ ╤В╨╡╨╗.',
    ),
    OrderItem(
      id: '#4822',
      clientName: '╨Я╨╡╤В╤А╨╛╨▓ ╨Р╨╗╨╡╨║╤Б╨░╨╜╨┤╤А',
      address: '╤Г╨╗. ╨Э╨░╨▒╨╡╤А╨╡╨╢╨╜╨░╤П, 18',
      district: '╨У╨╛╤А╨│╨╕╨┐╨┐╨╕╤П',
      price: 560,
      payment: PaymentType.cash,
      bottles: 2,
      lat: 44.8883,
      lng: 37.3082,
    ),
    OrderItem(
      id: '#4823',
      clientName: '╨б╨╝╨╕╤А╨╜╨╛╨▓╨░ ╨Х╨╗╨╡╨╜╨░',
      address: '╤Г╨╗. ╨Ы╨╡╨╜╨╕╨╜╨░, 102, ╨║╨▓. 3',
      district: '╨ж╨╡╨╜╤В╤А',
      price: 1120,
      payment: PaymentType.qr,
      bottles: 4,
      lat: 44.8932,
      lng: 37.3195,
      comment: '╨Ю╤Б╤В╨░╨▓╨╕╤В╤М ╤Г ╨┤╨▓╨╡╤А╨╕, ╨║╨╗╨╕╨╡╨╜╤В ╨╜╨░ ╤А╨░╨▒╨╛╤В╨╡',
    ),
    OrderItem(
      id: '#4824',
      clientName: '╨Ю╨Ю╨Ю ┬л╨а╨░╤Б╤Б╨▓╨╡╤В┬╗',
      address: '╤Г╨╗. ╨и╨╡╨▓╤З╨╡╨╜╨║╨╛, 7',
      district: '╨Я╤А╨╛╨╝. ╨╖╨╛╨╜╨░',
      price: 2800,
      payment: PaymentType.contract,
      bottles: 10,
      lat: 44.9021,
      lng: 37.3378,
      isDone: true,
    ),
    OrderItem(
      id: '#4825',
      clientName: '╨Ъ╨╛╨╖╨╗╨╛╨▓ ╨Ф╨╝╨╕╤В╤А╨╕╨╣',
      address: '╤Г╨╗. ╨б╨╛╨▓╨╡╤В╤Б╨║╨░╤П, 23, ╨║╨▓. 8',
      district: '╨Т╨╛╤Б╤В╨╛╨║',
      price: 280,
      payment: PaymentType.online,
      bottles: 1,
      lat: 44.8975,
      lng: 37.3298,
    ),
    OrderItem(
      id: '#4826',
      clientName: '╨д╤С╨┤╨╛╤А╨╛╨▓╨░ ╨Р╨╜╨╜╨░',
      address: '╨┐╨╡╤А. ╨Ь╨╛╤А╤Б╨║╨╛╨╣, 6, ╨║╨▓. 15',
      district: '╨ж╨╡╨╜╤В╤А',
      price: 560,
      payment: PaymentType.card,
      bottles: 2,
      lat: 44.8906,
      lng: 37.3128,
      isDone: true,
      comment: '╨б╨┤╨░╤З╨░ ╤Б 1000 тВ╜',
    ),
    OrderItem(
      id: '#4827',
      clientName: '╨Ч╨░╤Е╨░╤А╨╛╨▓ ╨Ш╨│╨╛╤А╤М',
      address: '╤Г╨╗. ╨У╨╛╤А╤М╨║╨╛╨│╨╛, 34, ╨║╨▓. 7',
      district: '╨Т╨╛╤Б╤В╨╛╨║',
      price: 840,
      payment: PaymentType.cash,
      bottles: 3,
      lat: 44.8965,
      lng: 37.3275,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _activeOrders = _allOrders.where((o) => !o.isDone).toList();
    _completedOrders = _allOrders.where((o) => o.isDone).toList();
    _buildTimeSlots();
    _initLocation();
    _mapController = MapController();
    _mapSheetController = DraggableScrollableController();
    _mapSheetController.addListener(() {
      // when sheet near top, consider it map-focused
      // (could be used to toggle UI later)
      setState(() {});
    });
  }

  void _buildTimeSlots() {
    // Group orders into time slots (example: 10:00тАУ14:00)
    // In a real app, this would come from the API or orders themselves
    final slot10_14 = _activeOrders.sublist(0, min(_activeOrders.length, 4));
    final slot14_18 = _activeOrders.sublist(min(_activeOrders.length, 4));

    _timeSlots = [];
    if (slot10_14.isNotEmpty) {
      _timeSlots.add(TimeSlot(label: '10:00 тАУ 14:00', orders: slot10_14));
    }
    if (slot14_18.isNotEmpty) {
      _timeSlots.add(TimeSlot(label: '14:00 тАУ 18:00', orders: slot14_18));
    }
  }

  Future<void> _initLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position =
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            ).timeout(
              const Duration(seconds: 12),
              onTimeout: () => throw Exception('GPS timeout'),
            );
        if (mounted) setState(() => _currentPosition = position);
      }
    } catch (_) {
      // GPS unavailable тАФ continue without it
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          if (_navIndex == 0) _buildTabSwitcher(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_navIndex) {
      case 0:
        if (_isMapView) {
          return Stack(children: [_buildActiveList(), _buildMapSheet()]);
        }
        return _buildActiveList();
      case 1:
        return _buildCompletedView();
      default:
        return _buildTabPlaceholder(_navIndex);
    }
  }

  Widget _buildMapSheet() {
    final initial = 0.42;
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
                color: _blue.withValues(alpha: 0.08),
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
                  color: const Color(0xFFD6E4F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _buildMapWidget(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapWidget() {
    // center map on first active order or a default point
    final center = _activeOrders.isNotEmpty
        ? ll.LatLng(_activeOrders[0].lat, _activeOrders[0].lng)
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
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        SimpleAttributionWidget(source: const Text('CartoDB')),
        MarkerLayer(
          markers: List.generate(_activeOrders.length, (i) {
            final o = _activeOrders[i];
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
                      color: _blue.withValues(alpha: 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: _orange,
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

  // тФАтФАтФА HEADER тФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФА

  Widget _buildHeader() {
    return Stack(
      children: [
        // Gradient overlay for system status bar visibility
        Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _blue.withValues(alpha: 0.6),
                _blue.withValues(alpha: 0.0),
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
                  '╨С╤Г╨╢╨╛╤А',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                _buildGpsIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsIndicator() {
    if (_isLocating) {
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
    if (_currentPosition != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_fixed_rounded, color: _liveGreen, size: 13),
          const SizedBox(width: 4),
          const Text(
            'GPS',
            style: TextStyle(
              color: _liveGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: _initLocation,
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

  // тФАтФАтФА TAB SWITCHER тФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФА

  Widget _buildTabSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF4FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTab('╨б╨┐╨╕╤Б╨╛╨║', Icons.list_rounded, !_isMapView),
            _buildTab('╨Ъ╨░╤А╤В╨░', Icons.map_outlined, _isMapView),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isMapView = label == '╨Ъ╨░╤А╤В╨░'),
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
                color: active ? _blue : const Color(0xFF8AACCC),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? _darkBlue : const Color(0xFF8AACCC),
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

  // тФАтФАтФА ACTIVE ORDERS LIST тФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФА

  Widget _buildActiveList() {
    if (_activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 56,
              color: _lightBlue.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '╨Т╤Б╨╡ ╨╖╨░╨║╨░╨╖╤Л ╨▓╤Л╨┐╨╛╨╗╨╜╨╡╨╜╤Л!',
              style: TextStyle(
                color: _darkBlue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '╨Ю╤В╨╗╨╕╤З╨╜╨░╤П ╤А╨░╨▒╨╛╤В╨░',
              style: TextStyle(
                color: const Color(0xFF6B8CAE).withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return AnimatedOpacity(
      opacity: _listOpacity,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _timeSlots.length,
        itemBuilder: (context, slotIndex) =>
            _buildTimeSlotGroup(_timeSlots[slotIndex], slotIndex),
      ),
    );
  }

  Widget _buildTimeSlotGroup(TimeSlot slot, int slotIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => slot.isExpanded = !slot.isExpanded),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.label,
                        style: const TextStyle(
                          color: _darkBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${slot.orders.length} ╨╖╨░╨║╨░╨╖╨╛╨▓',
                        style: TextStyle(
                          color: Color(0xFF6B8CAE).withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _buildRouteForSlot(slot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_orange, Color(0xFFFF9A3C)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '╨Ь╨░╤А╤И╤А╤Г╤В',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: slot.isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_less_rounded,
                    color: _blue,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (slot.isExpanded)
          Column(
            children: List.generate(slot.orders.length, (orderIndex) {
              final order = slot.orders[orderIndex];
              return _buildActiveCard(order, orderIndex + 1);
            }),
          ),
      ],
    );
  }

  Future<void> _buildRouteForSlot(TimeSlot slot) async {
    if (_isBuilding || slot.orders.isEmpty) return;
    final nav = Navigator.of(context);
    setState(() {
      _isBuilding = true;
      _listOpacity = 0.0;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    setState(() {
      _isBuilding = false;
      _listOpacity = 1.0;
    });

    nav.push(
      MaterialPageRoute(
        builder: (_) => RouteScreen(
          orders: List.from(slot.orders),
          startLat: _currentPosition?.latitude,
          startLng: _currentPosition?.longitude,
        ),
      ),
    );
  }

  // тФАтФАтФА COMPLETED VIEW тФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФА

  Widget _buildCompletedView() {
    if (_completedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: _green.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '╨Э╨╡╤В ╨▓╤Л╨┐╨╛╨╗╨╜╨╡╨╜╨╜╤Л╤Е ╨╖╨░╨║╨░╨╖╨╛╨▓',
              style: TextStyle(
                color: _darkBlue.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    final totalPrice = _completedOrders.fold<double>(0, (s, o) => s + o.price);
    final totalBottles = _completedOrders.fold<int>(0, (s, o) => s + o.bottles);
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              _buildStatChip(
                '${_completedOrders.length}',
                '╨╖╨░╨║╨░╨╖╨╛╨▓',
                _green,
              ),
              const SizedBox(width: 10),
              _buildStatChip('$totalBottles', '╨▒╤Г╤В.', _lightBlue),
              const SizedBox(width: 10),
              _buildStatChip('${totalPrice.toInt()} тВ╜', '', _orange),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _completedOrders.length,
            itemBuilder: (context, i) =>
                _buildCompletedCard(_completedOrders[i], i + 1),
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

  // тФАтФАтФА PLACEHOLDERS тФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФА

  Widget _buildTabPlaceholder(int index) {
    final labels = ['', '', '╨Ю╤В╤З╤С╤В', '╨Я╤А╨╛╤Д╨╕╨╗╤М'];
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
            color: _lightBlue.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            labels[index],
            style: TextStyle(
              color: _darkBlue.withValues(alpha: 0.5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // тФАтФАтФА ORDER CARDS тФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФА

  Widget _buildActiveCard(OrderItem order, int number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.10),
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
            Container(width: 4, color: _blue),
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
                        color: _orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _orange.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            color: _orange,
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

  Widget _buildCompletedCard(OrderItem order, int number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.10),
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
            Container(width: 4, color: _green),
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
                        color: _green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _green.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            color: _green,
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
                          color: _blue,
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
                            color: _green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '╨Т╤Л╨┐╨╛╨╗╨╜╨╡╨╜',
                            style: TextStyle(
                              color: _green,
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
                      color: _darkBlue,
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
                  '${order.price.toInt()} тВ╜',
                  style: const TextStyle(
                    color: _darkBlue,
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
                  color: const Color(0xFFEEF4FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: _blue,
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
              color: Color(0xFF8AACCC),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                order.address,
                style: const TextStyle(color: Color(0xFF6B8CAE), fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FB),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                order.district,
                style: const TextStyle(
                  color: _blue,
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
              const Icon(Icons.info_outline_rounded, size: 13, color: _orange),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.comment!,
                  style: TextStyle(
                    color: _orange.withValues(alpha: 0.85),
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
            const Icon(Icons.water_drop_outlined, size: 15, color: _lightBlue),
            const SizedBox(width: 4),
            Text(
              '${order.bottles} ╨▒╤Г╤В.',
              style: const TextStyle(
                color: Color(0xFF6B8CAE),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_orange, Color(0xFFFF9A3C)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '╨Ь╨░╤А╤И╤А╤Г╤В',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ],
                ),
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
        color = _blue;
        label = '╨Ъ╨░╤А╤В╨░';
      case PaymentType.cash:
        icon = Icons.payments_outlined;
        color = _green;
        label = '╨Э╨░╨╗';
      case PaymentType.qr:
        icon = Icons.qr_code_rounded;
        color = const Color(0xFF7B3FE4);
        label = 'QR';
      case PaymentType.online:
        icon = Icons.smartphone_rounded;
        color = _orange;
        label = '╨Ю╨╜╨╗╨░╨╣╨╜';
      case PaymentType.contract:
        icon = Icons.description_outlined;
        color = const Color(0xFF8AACCC);
        label = '╨Ф╨╛╨│╨╛╨▓╨╛╤А';
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

  // тФАтФАтФА BOTTOM NAV тФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФАтФА

  Widget _buildBottomNav() {
    const items = [
      (
        Icons.local_shipping_outlined,
        Icons.local_shipping_rounded,
        '╨Ч╨░╨║╨░╨╖╤Л',
      ),
      (
        Icons.check_circle_outline_rounded,
        Icons.check_circle_rounded,
        '╨Т╤Л╨┐╨╛╨╗╨╜╨╡╨╜╨╛',
      ),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded, '╨Ю╤В╤З╤С╤В'),
      (Icons.person_outline_rounded, Icons.person_rounded, '╨Я╤А╨╛╤Д╨╕╨╗╤М'),
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
              final active = _navIndex == i;
              final (iconOut, iconFill, label) = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _navIndex = i;
                    _isMapView = false;
                  }),
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
                              ? _blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          active ? iconFill : iconOut,
                          color: active ? _blue : const Color(0xFF8AACCC),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: active ? _blue : const Color(0xFF8AACCC),
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
