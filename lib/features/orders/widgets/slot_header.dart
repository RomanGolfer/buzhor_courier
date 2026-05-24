import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/features/orders/models/time_slot.dart';
import 'package:buzhor_courier/features/orders/screens/order_detail_screen.dart';
import 'package:buzhor_courier/features/orders/widgets/order_card.dart';
import 'package:flutter/material.dart';

part 'slot_header_summary.dart';
part 'slot_orders_list.dart';

const double _routeActionColumnWidth = 112;

class SlotHeader extends StatelessWidget {
  final TimeSlot slot;
  final Set<String> newOrderIds;
  final VoidCallback onToggle;
  final VoidCallback onBuildRoute;
  final ValueChanged<String> onOrderOpen;

  const SlotHeader({
    super.key,
    required this.slot,
    this.newOrderIds = const {},
    required this.onToggle,
    required this.onBuildRoute,
    required this.onOrderOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.blue.withValues(alpha: 0.45),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SlotHeaderSummary(
            slot: slot,
            onToggle: onToggle,
            onBuildRoute: onBuildRoute,
          ),
          if (slot.isExpanded)
            _SlotOrdersList(
              slot: slot,
              newOrderIds: newOrderIds,
              onOrderOpen: onOrderOpen,
            ),
        ],
      ),
    );
  }
}
