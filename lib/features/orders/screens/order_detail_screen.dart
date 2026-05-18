import 'dart:async';

import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/core/services/navigation_service.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:buzhor_courier/features/orders/screens/qr_scanner_screen.dart';
import 'package:buzhor_courier/features/orders/services/payment_status_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

part 'order_detail/header.dart';
part 'order_detail/address_card.dart';
part 'order_detail/communication_cards.dart';
part 'order_detail/order_info_cards.dart';
part 'order_detail/bottom_sheets.dart';
part 'order_detail/shared_widgets.dart';

const _dispatcherPhone = '+79385358777';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final OrderItem order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late int _bottles;
  late PaymentType _paymentType;
  final Map<String, int> _extras = {};
  double _dispatcherReveal = 0;
  Timer? _dispatcherHideTimer;

  @override
  void initState() {
    super.initState();
    _bottles = widget.order.deliveredBottles ?? widget.order.bottles;
    _paymentType = widget.order.confirmedPayment ?? widget.order.payment;
    _extras.addAll(widget.order.extras);
  }

  @override
  void dispose() {
    _dispatcherHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
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
                      isReadOnly: order.isClosed,
                      onBottlesChanged: (value) =>
                          setState(() => _bottles = value),
                      onPaymentTypeChanged: (value) =>
                          setState(() => _paymentType = value),
                      onExtrasChanged: (value) => setState(() {
                        _extras
                          ..clear()
                          ..addAll(value);
                      }),
                    ),
                    if (!order.isClosed && _paymentType == PaymentType.qr) ...[
                      const SizedBox(height: 12),
                      _PaymentQrCard(order: order),
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
                    _OrderItemsCard(order: order),
                  ],
                ),
              ),
            ],
          ),
          if (!order.isClosed)
            _DispatcherHeaderPanel(
              order: order,
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
          paymentType: _paymentType,
          extras: _extras,
          scannedItems: confirmation.scannedItems,
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
  final String? comment;

  const _DeliveryConfirmation({
    required this.returnedBottles,
    required this.scannedItems,
    required this.comment,
  });
}

class _FailureConfirmation {
  final String reason;

  const _FailureConfirmation({required this.reason});
}
