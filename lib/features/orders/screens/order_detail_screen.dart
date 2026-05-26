import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:buzhor_courier/core/config/backend_app_config.dart';
import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/core/services/navigation_service.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:buzhor_courier/features/orders/screens/qr_scanner_screen.dart';
import 'package:buzhor_courier/features/orders/services/order_pricing_service.dart';
import 'package:buzhor_courier/features/orders/services/payment_status_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

part 'order_detail/header.dart';
part 'order_detail/address_card.dart';
part 'order_detail/address_card_sections.dart';
part 'order_detail/address_card_payment.dart';
part 'order_detail/address_card_extras.dart';
part 'order_detail/communication_cards.dart';
part 'order_detail/dispatcher_header_panel.dart';
part 'order_detail/quick_sms_card.dart';
part 'order_detail/order_items_card.dart';
part 'order_detail/payment_qr_card.dart';
part 'order_detail/delivery_result_card.dart';
part 'order_detail/comment_card.dart';
part 'order_detail/bottom_buttons.dart';
part 'order_detail/bottom_sheets.dart';
part 'order_detail/delivery_sheet_actions.dart';
part 'order_detail/delivery_sheet_sections.dart';
part 'order_detail/delivery_sheet_payment_sections.dart';
part 'order_detail/delivery_summary.dart';
part 'order_detail/failure_sheet.dart';
part 'order_detail/shared_widgets.dart';
part 'order_detail/payment_qr_panel.dart';
part 'order_detail/payment_qr_full_screen.dart';
part 'order_detail/payment_qr_full_screen_widgets.dart';
part 'order_detail/payment_qr_share_actions.dart';
part 'order_detail/payment_qr_status_polling.dart';
part 'order_detail/payment_qr_cards.dart';
part 'order_detail/payment_qr_payload.dart';
part 'order_detail/order_detail_labels.dart';
part 'order_detail/order_detail_confirmations.dart';
part 'order_detail/order_detail_marking_helpers.dart';
part 'order_detail/order_detail_actions.dart';
part 'order_detail/order_detail_dispatcher_panel.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final OrderItem order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late int _bottles;
  late PaymentType _paymentType;
  PaymentType? _pendingPaymentType;
  final Map<String, int> _extras = {};
  final Map<String, int> _scannedItems = {};
  final Map<String, List<String>> _markingCodes = {};
  double _dispatcherReveal = 0;
  Timer? _dispatcherHideTimer;

  double get _currentTotal =>
      OrderPricingService.orderTotal(bottles: _bottles, extras: _extras);

  OrderItem _resolveOrder(OrdersState state) {
    return state.activeOrders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => state.completedOrders.firstWhere(
        (o) => o.id == widget.order.id,
        orElse: () => widget.order,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = _resolveOrder(ref.read(ordersProvider));
    _bottles = initial.deliveredBottles ?? initial.bottles;
    _paymentType = initial.confirmedPayment ?? initial.payment;
    _extras.addAll(initial.extras);
    _scannedItems.addAll(initial.scannedItems);
    _markingCodes.addAll(_copyMarkingCodes(initial.markingCodes));
    if (_scannedItems.isEmpty && _markingCodes.isNotEmpty) {
      _scannedItems.addAll(_countsFromMarkingCodes(_markingCodes));
    }
  }

  void _setOrderDetailState(VoidCallback fn) => setState(fn);

  @override
  void dispose() {
    _dispatcherHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(ordersProvider);
    final appConfig =
        ref.watch(backendAppConfigProvider).valueOrNull ??
        BackendAppConfig.fallback;

    _listenForOrderUpdates();

    final order = _resolveOrder(providerState);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(
                order: order,
                onDispatcherTap: order.isClosed ? null : _toggleDispatcherPanel,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    _AddressCard(
                      order: order,
                      bottles: _bottles,
                      paymentType: _paymentType,
                      extras: _extras,
                      totalPrice: _currentTotal,
                      isReadOnly: order.isClosed,
                      onBottlesChanged: _onBottlesChanged,
                      onPaymentTypeChanged: _onPaymentTypeChanged,
                      onExtrasChanged: _onExtrasChanged,
                    ),
                    if (!order.isClosed && _paymentType == PaymentType.qr) ...[
                      const SizedBox(height: 12),
                      _PaymentQrCard(order: order, amount: _currentTotal),
                    ],
                    if (order.isClosed) ...[
                      const SizedBox(height: 12),
                      _DeliveryResultCard(order: order),
                    ],
                    if (!order.isClosed && order.comment != null) ...[
                      const SizedBox(height: 12),
                      _CommentCard(comment: order.comment!),
                    ],
                    if (!order.isClosed) ...[
                      const SizedBox(height: 12),
                      _QuickSmsCard(order: order),
                    ],
                    const SizedBox(height: 12),
                    _ClientCard(order: order),
                    const SizedBox(height: 12),
                    _OrderItemsCard(
                      order: order,
                      bottles: _bottles,
                      totalPrice: _currentTotal,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!order.isClosed)
            _DispatcherHeaderPanel(
              order: order,
              dispatcherPhone: appConfig.dispatcherPhone,
              reveal: _dispatcherReveal,
              onAction: _hideDispatcherPanel,
            ),
        ],
      ),
      bottomNavigationBar: order.isClosed
          ? null
          : _BottomButtons(
              order: order,
              bottles: _bottles,
              paymentType: _paymentType,
              extras: _extras,
              scannedItems: _scannedItems,
              markingCodes: _markingCodes,
              totalPrice: _currentTotal,
              onPaymentTypeChanged: _onPaymentTypeChanged,
              onScannedItemsChanged: _onScannedItemsChanged,
              onMarkingCodesChanged: _onMarkingCodesChanged,
              onDelivered: _completeOrder,
              onFailed: _failOrder,
            ),
    );
  }
}
