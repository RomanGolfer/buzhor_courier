import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/core/services/navigation_service.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _bottles = widget.order.bottles;
    _paymentType = widget.order.payment;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
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
                  onBottlesChanged: (value) => setState(() => _bottles = value),
                  onPaymentTypeChanged: (value) =>
                      setState(() => _paymentType = value),
                  onExtrasChanged: (value) => setState(() {
                    _extras
                      ..clear()
                      ..addAll(value);
                  }),
                ),
                if (order.comment != null) ...[
                  const SizedBox(height: 12),
                  _CommentCard(comment: order.comment!),
                ],
                const SizedBox(height: 12),
                _DispatcherCard(order: order),
                const SizedBox(height: 12),
                _QuickSmsCard(order: order),
                const SizedBox(height: 12),
                _ClientCard(order: order),
                const SizedBox(height: 12),
                _OrderItemsCard(order: order),
              ],
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

  void _completeOrder(_DeliveryConfirmation confirmation) {
    ref
        .read(ordersProvider.notifier)
        .completeOrder(
          widget.order.id,
          bottles: _bottles,
          returnedBottles: confirmation.returnedBottles,
          paymentType: _paymentType,
          extras: _extras,
          comment: confirmation.comment,
        );
  }

  void _failOrder(_FailureConfirmation confirmation) {
    ref
        .read(ordersProvider.notifier)
        .failOrder(widget.order.id, reason: confirmation.reason);
  }
}

class _DeliveryConfirmation {
  final int returnedBottles;
  final String? comment;

  const _DeliveryConfirmation({
    required this.returnedBottles,
    required this.comment,
  });
}

class _FailureConfirmation {
  final String reason;

  const _FailureConfirmation({required this.reason});
}
