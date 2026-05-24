part of '../order_detail_screen.dart';

class _BottomButtons extends StatelessWidget {
  final OrderItem order;
  final int bottles;
  final PaymentType paymentType;
  final Map<String, int> extras;
  final Map<String, int> scannedItems;
  final Map<String, List<String>> markingCodes;
  final double totalPrice;
  final ValueChanged<PaymentType> onPaymentTypeChanged;
  final ValueChanged<Map<String, int>> onScannedItemsChanged;
  final ValueChanged<Map<String, List<String>>> onMarkingCodesChanged;
  final Future<void> Function(_DeliveryConfirmation confirmation) onDelivered;
  final Future<void> Function(_FailureConfirmation confirmation) onFailed;

  const _BottomButtons({
    required this.order,
    required this.bottles,
    required this.paymentType,
    required this.extras,
    required this.scannedItems,
    required this.markingCodes,
    required this.totalPrice,
    required this.onPaymentTypeChanged,
    required this.onScannedItemsChanged,
    required this.onMarkingCodesChanged,
    required this.onDelivered,
    required this.onFailed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark(context) ? 0.24 : 0.06,
            ),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _FailureSheet(onConfirm: onFailed),
                ),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade400, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Не доставлен',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _DeliverySheet(
                    order: order,
                    bottles: bottles,
                    paymentType: paymentType,
                    extras: extras,
                    scannedItems: scannedItems,
                    markingCodes: markingCodes,
                    totalPrice: totalPrice,
                    onPaymentTypeChanged: onPaymentTypeChanged,
                    onScannedItemsChanged: onScannedItemsChanged,
                    onMarkingCodesChanged: onMarkingCodesChanged,
                    onConfirm: onDelivered,
                  ),
                ),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.orange, AppColors.orangeLight],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Доставлен',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
