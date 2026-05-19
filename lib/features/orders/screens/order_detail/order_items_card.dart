part of '../order_detail_screen.dart';

class _OrderItemsCard extends StatelessWidget {
  final OrderItem order;
  final int bottles;
  final double totalPrice;
  const _OrderItemsCard({
    required this.order,
    required this.bottles,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Товары',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Вода питьевая 19л',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '× $bottles',
                style: const TextStyle(color: AppColors.grayBlue, fontSize: 14),
              ),
              const SizedBox(width: 12),
              Text(
                '${OrderPricingService.waterTotal(bottles).toInt()} ₽',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!order.isClosed && order.scannedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.green,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${order.scannedItems['water'] ?? 0} / $bottles отсканировано',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const _RowDivider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Итого',
                style: TextStyle(color: AppColors.grayBlue, fontSize: 14),
              ),
              Text(
                '${totalPrice.toInt()} ₽',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'К оплате',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${totalPrice.toInt()} ₽',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
