import 'dart:async';

import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/core/services/navigation_service.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:buzhor_courier/features/orders/screens/qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const _dispatcherRevealDistance = 180.0;

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
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(order: order),
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
            _DispatcherEdgePanel(
              order: order,
              reveal: _dispatcherReveal,
              onAction: _hideDispatcherPanel,
              onDragUpdate: _handleDispatcherDragUpdate,
              onDragEnd: _handleDispatcherDragEnd,
            ),
          if (!order.isClosed && _dispatcherReveal == 0)
            Positioned(
              right: 0,
              top: MediaQuery.paddingOf(context).top + 112,
              bottom: 96,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: _handleDispatcherDragUpdate,
                onHorizontalDragEnd: _handleDispatcherDragEnd,
                child: SizedBox(
                  width: 28,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 4,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.22),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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

  void _handleDispatcherDragUpdate(DragUpdateDetails details) {
    if (widget.order.isClosed) return;
    _dispatcherHideTimer?.cancel();
    final nextReveal =
        (_dispatcherReveal - (details.delta.dx / _dispatcherRevealDistance))
            .clamp(0.0, 1.0);
    if (nextReveal != _dispatcherReveal) {
      setState(() => _dispatcherReveal = nextReveal);
    }
  }

  void _handleDispatcherDragEnd(DragEndDetails details) {
    if (_dispatcherReveal >= 0.35) {
      setState(() => _dispatcherReveal = 1);
      _scheduleDispatcherHide();
    } else {
      _hideDispatcherPanel();
    }
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
  PaymentType.card => 'Карта',
  PaymentType.cash => 'Наличные',
  PaymentType.qr => 'QR-код',
  PaymentType.online => 'Онлайн',
  PaymentType.contract => 'Договор',
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
