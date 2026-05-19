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
  final VoidCallback onToggle;
  final VoidCallback onBuildRoute;

  const SlotHeader({
    super.key,
    required this.slot,
    required this.onToggle,
    required this.onBuildRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SlotHeaderSummary(
                    slot: slot,
                    onToggle: onToggle,
                    onBuildRoute: onBuildRoute,
                  ),
                  if (slot.isExpanded) _SlotOrdersList(slot: slot),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
