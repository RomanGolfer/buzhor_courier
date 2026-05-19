import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:buzhor_courier/core/services/navigation_service.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter/material.dart';

part 'order_card_badges.dart';
part 'order_card_content.dart';
part 'order_card_content_sections.dart';

class OrderCard extends StatelessWidget {
  final OrderItem order;
  final int number;
  final VoidCallback? onTap;
  final bool showRouteButton;

  const OrderCard({
    super.key,
    required this.order,
    required this.number,
    this.onTap,
    this.showRouteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final borderColor = order.isFailed
        ? Colors.red.shade400
        : order.isClosed
        ? AppColors.green
        : AppColors.blue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: isDark ? 12 : 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: borderColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NumberBadge(order: order, number: number),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CardContent(
                          order: order,
                          showRouteButton: showRouteButton,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
