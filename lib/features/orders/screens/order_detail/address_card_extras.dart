part of '../order_detail_screen.dart';

const _addressExtraOptions = [
  OrderPricingService.petBottleDepositName,
  OrderPricingService.mechanicalPumpName,
  'Кулер',
  'Другое',
];

extension _AddressCardExtras on _AddressCard {
  void _showExtrasSheet(BuildContext context) {
    final sheetExtras = Map<String, int>.from(extras);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Выберите допы',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._addressExtraOptions.map((option) {
                    final count = sheetExtras[option] ?? 0;
                    final unitPrice = OrderPricingService.extraUnitPrice(
                      option,
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: unitPrice > 0
                          ? Text('$unitPrice ₽')
                          : const Text('Цена уточняется'),
                      trailing: count > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'x$count',
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        setSheetState(() {
                          sheetExtras[option] = (sheetExtras[option] ?? 0) + 1;
                        });
                        onExtrasChanged(sheetExtras);
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Готово',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
