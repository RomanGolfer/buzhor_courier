part of '../order_detail_screen.dart';

class _AddressCard extends StatelessWidget {
  final OrderItem order;
  final int bottles;
  final PaymentType paymentType;
  final Map<String, int> extras;
  final ValueChanged<int> onBottlesChanged;
  final ValueChanged<PaymentType> onPaymentTypeChanged;
  final ValueChanged<Map<String, int>> onExtrasChanged;

  const _AddressCard({
    required this.order,
    required this.bottles,
    required this.paymentType,
    required this.extras,
    required this.onBottlesChanged,
    required this.onPaymentTypeChanged,
    required this.onExtrasChanged,
  });

  static const _extraOptions = ['Тара 19л', 'Помпа', 'Кулер', 'Другое'];
  static const _paymentCycle = [
    PaymentType.card,
    PaymentType.cash,
    PaymentType.online,
    PaymentType.contract,
  ];

  bool get _isPaid => paymentType == PaymentType.online;

  String _paymentLabel(PaymentType t) => switch (t) {
    PaymentType.card => 'Карта',
    PaymentType.cash => 'Нал',
    PaymentType.qr => 'QR-код',
    PaymentType.online => 'Онлайн',
    PaymentType.contract => 'Договор',
  };

  String _paymentIcon(PaymentType t) => switch (t) {
    PaymentType.card => '💳',
    PaymentType.cash => '💵',
    PaymentType.qr => '📱',
    PaymentType.online => '✅',
    PaymentType.contract => '📄',
  };

  Color _paymentColor(PaymentType t) => switch (t) {
    PaymentType.card => AppColors.blue,
    PaymentType.cash => AppColors.green,
    PaymentType.qr => AppColors.blue,
    PaymentType.online => AppColors.green,
    PaymentType.contract => AppColors.grayBlue,
  };

  void _cyclePayment() {
    if (_isPaid) return;
    final normalizedType = _paymentCycle.contains(paymentType)
        ? paymentType
        : PaymentType.card;
    final index = _paymentCycle.indexOf(normalizedType);
    final nextIndex = (index + 1) % _paymentCycle.length;
    onPaymentTypeChanged(_paymentCycle[nextIndex]);
  }

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
                  const Text(
                    'Выберите допы',
                    style: TextStyle(
                      color: AppColors.darkBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._extraOptions.map((option) {
                    final count = sheetExtras[option] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.blue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order.address,
                  style: const TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    NavigationService.openExternalRoute(order.lat, order.lng),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.orange, AppColors.orangeLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const _RowDivider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Бутылей',
                      style: TextStyle(color: AppColors.grayBlue, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CounterButton(
                          icon: Icons.remove,
                          onTap: () {
                            if (bottles > 0) {
                              onBottlesChanged(bottles - 1);
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$bottles',
                          style: const TextStyle(
                            color: AppColors.darkBlue,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _CounterButton(
                          icon: Icons.add,
                          onTap: () => onBottlesChanged(bottles + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 76,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.divider,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Оплата',
                      style: TextStyle(color: AppColors.grayBlue, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _isPaid
                        ? _PaymentChip(
                            label: 'Оплачено ✓',
                            color: AppColors.green,
                          )
                        : GestureDetector(
                            onTap: _cyclePayment,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _paymentColor(
                                  paymentType,
                                ).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _paymentColor(
                                    paymentType,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _paymentIcon(paymentType),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: _paymentColor(paymentType),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _paymentLabel(paymentType),
                                    style: TextStyle(
                                      color: _paymentColor(paymentType),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
          const _RowDivider(),
          Row(
            children: [
              const Text(
                'Дополнительно',
                style: TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showExtrasSheet(context),
                child: const Text(
                  '+ Добавить',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: extras.entries.map((entry) {
                return Chip(
                  label: Text(
                    '${entry.key} ×${entry.value}',
                    style: const TextStyle(
                      color: AppColors.darkBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: AppColors.grayBlueLight.withValues(
                    alpha: 0.16,
                  ),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    final updatedExtras = Map<String, int>.from(extras)
                      ..remove(entry.key);
                    onExtrasChanged(updatedExtras);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Dispatcher card ──────────────────────────────────────────────────────────
