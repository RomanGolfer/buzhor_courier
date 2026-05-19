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
          _buildAddressRow(context),
          if (!isReadOnly) ...[
            const _RowDivider(),
            _buildBottlePaymentRow(context),
          ],
          const _RowDivider(),
          _buildExtrasSection(context),
        ],
      ),
    );
  }
}

// ─── Dispatcher card ──────────────────────────────────────────────────────────
