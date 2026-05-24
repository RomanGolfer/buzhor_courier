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
part 'order_detail/delivery_sheet_sections.dart';
part 'order_detail/delivery_sheet_payment_sections.dart';
part 'order_detail/delivery_summary.dart';
part 'order_detail/failure_sheet.dart';
part 'order_detail/shared_widgets.dart';
part 'order_detail/payment_qr_panel.dart';
part 'order_detail/payment_qr_full_screen.dart';
part 'order_detail/payment_qr_full_screen_widgets.dart';
part 'order_detail/payment_qr_cards.dart';
part 'order_detail/payment_qr_payload.dart';

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

  @override
  void dispose() {
    _dispatcherHideTimer?.cancel();
    super.dispose();
  }

  void _onBottlesChanged(int value) {
    setState(() => _bottles = value);
    _syncToProvider();
  }

  void _onPaymentTypeChanged(PaymentType value) {
    setState(() {
      _paymentType = value;
      _pendingPaymentType = value;
    });
    _syncToProvider(
      failureMessage:
          'Не удалось сразу сохранить способ оплаты. Выбор оставлен, попробуйте еще раз.',
    );
  }

  void _onExtrasChanged(Map<String, int> value) {
    setState(() {
      _extras
        ..clear()
        ..addAll(value);
    });
    _syncToProvider();
  }

  void _onScannedItemsChanged(Map<String, int> value) {
    setState(() {
      _scannedItems
        ..clear()
        ..addAll(value);
    });
    _syncToProvider();
  }

  void _onMarkingCodesChanged(Map<String, List<String>> value) {
    final markingCounts = _countsFromMarkingCodes(value);
    setState(() {
      _markingCodes
        ..clear()
        ..addAll(_copyMarkingCodes(value));
      _scannedItems
        ..clear()
        ..addAll(markingCounts);
    });
    _syncToProvider();
  }

  void _syncToProvider({String? failureMessage}) {
    final current = _resolveOrder(ref.read(ordersProvider));
    if (current.isClosed) return;
    final updatedOrder = current.copyWith(
      payment: _paymentType,
      deliveredBottles: _bottles,
      extras: Map.of(_extras),
      scannedItems: Map.of(_scannedItems),
      markingCodes: _copyMarkingCodes(_markingCodes),
    );

    unawaited(
      ref
          .read(ordersProvider.notifier)
          .updateOrder(updatedOrder)
          .then((_) {
            if (!mounted || _pendingPaymentType != updatedOrder.payment) {
              return;
            }
            setState(() => _pendingPaymentType = null);
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!mounted || failureMessage == null) return;
            _showSyncError(failureMessage);
          }),
    );
  }

  void _showSyncError(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('orderDetailSyncErrorSnackBar'),
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(ordersProvider);
    final appConfig =
        ref.watch(backendAppConfigProvider).valueOrNull ??
        BackendAppConfig.fallback;

    ref.listen<OrdersState>(ordersProvider, (_, next) {
      final updated = next.activeOrders.firstWhere(
        (o) => o.id == widget.order.id,
        orElse: () => widget.order,
      );
      if (updated.isClosed) return;
      final pendingPaymentType = _pendingPaymentType;
      if (pendingPaymentType != null) {
        if (updated.payment == pendingPaymentType &&
            pendingPaymentType == _paymentType) {
          setState(() => _pendingPaymentType = null);
        }
        return;
      }
      if (updated.payment != _paymentType) {
        setState(() => _paymentType = updated.payment);
      }
    });

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

  Future<void> _completeOrder(_DeliveryConfirmation confirmation) {
    return ref
        .read(ordersProvider.notifier)
        .completeOrder(
          widget.order.id,
          bottles: _bottles,
          returnedBottles: confirmation.returnedBottles,
          paymentType: confirmation.paymentType,
          extras: _extras,
          scannedItems: confirmation.scannedItems,
          markingCodes: confirmation.markingCodes,
          comment: confirmation.comment,
        );
  }

  Future<void> _failOrder(_FailureConfirmation confirmation) {
    return ref
        .read(ordersProvider.notifier)
        .failOrder(widget.order.id, reason: confirmation.reason);
  }

  void _toggleDispatcherPanel() {
    if (_dispatcherReveal == 1) {
      _hideDispatcherPanel();
      return;
    }
    _dispatcherHideTimer?.cancel();
    setState(() => _dispatcherReveal = 1);
    _scheduleDispatcherHide();
  }

  void _scheduleDispatcherHide() {
    _dispatcherHideTimer?.cancel();
    _dispatcherHideTimer = Timer(
      const Duration(seconds: 2),
      _hideDispatcherPanel,
    );
  }

  void _hideDispatcherPanel() {
    _dispatcherHideTimer?.cancel();
    if (!mounted || _dispatcherReveal == 0) return;
    setState(() => _dispatcherReveal = 0);
  }
}

String _paymentLabel(PaymentType type) => switch (type) {
  PaymentType.card => 'Картой курьеру',
  PaymentType.cash => 'Наличные',
  PaymentType.qr => 'Онлайн оплата',
  PaymentType.online => 'Оплачено',
  PaymentType.contract => 'По договору',
};

class _DeliveryConfirmation {
  final int returnedBottles;
  final Map<String, int> scannedItems;
  final Map<String, List<String>> markingCodes;
  final PaymentType paymentType;
  final String? comment;

  const _DeliveryConfirmation({
    required this.returnedBottles,
    required this.scannedItems,
    required this.markingCodes,
    required this.paymentType,
    required this.comment,
  });
}

class _FailureConfirmation {
  final String reason;

  const _FailureConfirmation({required this.reason});
}

Map<String, List<String>> _copyMarkingCodes(
  Map<String, List<String>> markingCodes,
) {
  if (markingCodes.isEmpty) return {};
  return markingCodes.map(
    (key, codes) => MapEntry(key, List<String>.unmodifiable(codes)),
  );
}

Map<String, int> _countsFromMarkingCodes(
  Map<String, List<String>> markingCodes,
) {
  if (markingCodes.isEmpty) return {};
  return markingCodes.map((key, codes) => MapEntry(key, codes.length));
}
