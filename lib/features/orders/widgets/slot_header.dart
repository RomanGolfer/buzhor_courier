import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/features/orders/models/time_slot.dart';
import 'package:buzhor_courier/features/orders/widgets/order_card.dart';
import 'package:flutter/material.dart';

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
    final totalBottles = slot.orders.fold<int>(0, (sum, order) => sum + order.bottles);
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
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blue.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        slot.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.darkBlue,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.water_drop_rounded,
                                      size: 13,
                                      color: AppColors.lightBlue,
                                    ),
                                    const SizedBox(width: 3),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: AppColors.blue.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$totalBottles',
                                          style: const TextStyle(
                                            color: AppColors.blue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${slot.orders.length} заказов',
                                  style: TextStyle(
                                    color: AppColors.grayBlue.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onBuildRoute,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.orange, AppColors.orangeLight],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.route_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: slot.isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.expand_less_rounded,
                              color: AppColors.blue,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (slot.isExpanded)
                    Column(
                      children: List.generate(
                        slot.orders.length,
                        (i) => OrderCard(
                          order: slot.orders[i],
                          number: i + 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
