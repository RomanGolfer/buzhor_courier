part of '../order_detail_screen.dart';

class _AddressCard extends StatelessWidget {
  final OrderItem order;
  final int bottles;
  final PaymentType paymentType;
  final Map<String, int> extras;
  final double totalPrice;
  final bool isReadOnly;
  final ValueChanged<int> onBottlesChanged;
  final ValueChanged<PaymentType> onPaymentTypeChanged;
  final ValueChanged<Map<String, int>> onExtrasChanged;

  const _AddressCard({
    required this.order,
    required this.bottles,
    required this.paymentType,
    required this.extras,
    required this.totalPrice,
    required this.isReadOnly,
    required this.onBottlesChanged,
    required this.onPaymentTypeChanged,
    required this.onExtrasChanged,
  });

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
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isReadOnly) ...[
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
            ],
          ),
          if (!isReadOnly) ...[
            const _RowDivider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Бутылей',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (!isReadOnly) ...[
                            _CounterButton(
                              icon: Icons.remove,
                              onTap: () {
                                if (bottles > 0) {
                                  onBottlesChanged(bottles - 1);
                                }
                              },
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            '$bottles',
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!isReadOnly) ...[
                            const SizedBox(width: 10),
                            _CounterButton(
                              icon: Icons.add,
                              onTap: () => onBottlesChanged(bottles + 1),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 76,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppColors.dividerColor(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Оплата',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isPaid || isReadOnly
                          ? _PaymentChip(
                              label: _isPaid
                                  ? 'Оплачено ✓'
                                  : _paymentLabel(paymentType),
                              color: _paymentFgColor(context, paymentType),
                              bgColor: _paymentBgColor(context, paymentType),
                            )
                          : GestureDetector(
                              onTap: () => _showPaymentSheet(context),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _paymentBgColor(context, paymentType),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _paymentFgColor(
                                      context,
                                      paymentType,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _paymentIconWidget(context, paymentType),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _compactPaymentLabel(paymentType),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _paymentFgColor(
                                            context,
                                            paymentType,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
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
          ],
          const _RowDivider(),
          Row(
            children: [
              Text(
                'Дополнительно',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!isReadOnly)
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
          if (!isReadOnly && extras.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: extras.entries.map((entry) {
                return Chip(
                  label: Text(
                    '${entry.key} ×${entry.value}',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: AppColors.grayBlueLight.withValues(
                    alpha: 0.16,
                  ),
                  deleteIcon: isReadOnly
                      ? null
                      : const Icon(Icons.close, size: 18),
                  onDeleted: isReadOnly
                      ? null
                      : () {
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
