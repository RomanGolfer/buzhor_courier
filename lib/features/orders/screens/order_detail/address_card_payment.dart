part of '../order_detail_screen.dart';

extension _AddressCardPayment on _AddressCard {
  bool get _isPaid => paymentType == PaymentType.online;

  String _compactPaymentLabel(PaymentType t) => switch (t) {
    PaymentType.card => 'Картой',
    PaymentType.contract => 'Договор',
    PaymentType.cash => 'Наличные',
    PaymentType.qr => 'Онлайн',
    PaymentType.online => 'Оплачено',
  };

  String _paymentIcon(PaymentType t) => switch (t) {
    PaymentType.card => '💳',
    PaymentType.cash => '💵',
    PaymentType.qr => '🔳',
    PaymentType.online => '✅',
    PaymentType.contract => '📄',
  };

  Widget _paymentIconWidget(BuildContext context, PaymentType t) {
    if (t == PaymentType.online) {
      return Icon(
        Icons.contactless,
        color: _paymentFgColor(context, t),
        size: 20,
      );
    }
    if (t == PaymentType.qr) {
      return Icon(Icons.qr_code, color: _paymentFgColor(context, t), size: 20);
    }
    return Text(_paymentIcon(t), style: const TextStyle(fontSize: 18));
  }

  Color _paymentFgColor(BuildContext context, PaymentType t) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return switch (t) {
        PaymentType.card => const Color(0xFF8AACCC),
        PaymentType.cash => const Color(0xFF4CAF50),
        PaymentType.qr => const Color(0xFF9C6FD6),
        PaymentType.online => const Color(0xFF26A96C),
        PaymentType.contract => const Color(0xFF888888),
      };
    }
    return switch (t) {
      PaymentType.card => const Color(0xFF1B5FA8),
      PaymentType.cash => const Color(0xFFB76A00),
      PaymentType.qr => const Color(0xFF7B35D8),
      PaymentType.online => const Color(0xFF2F8F3A),
      PaymentType.contract => const Color(0xFF60758A),
    };
  }

  Color _paymentBgColor(BuildContext context, PaymentType t) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return switch (t) {
        PaymentType.card => const Color(0xFF2A3A4A),
        PaymentType.cash => const Color(0xFF1A3A1A),
        PaymentType.qr => const Color(0xFF2D1F4A),
        PaymentType.online => const Color(0xFF1A3A2A),
        PaymentType.contract => const Color(0xFF2A2A2A),
      };
    }
    return switch (t) {
      PaymentType.card => const Color(0xFFEAF3FF),
      PaymentType.cash => const Color(0xFFFFF3DF),
      PaymentType.qr => const Color(0xFFF1E8FF),
      PaymentType.online => const Color(0xFFE6F5E7),
      PaymentType.contract => const Color(0xFFEEF2F6),
    };
  }

  void _showPaymentSheet(BuildContext context) {
    if (_isPaid || isReadOnly) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Выберите способ оплаты',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    key: const Key('paymentTypeCardOption'),
                    title: const Text('Картой курьеру'),
                    leading: Text(_paymentIcon(PaymentType.card)),
                    onTap: () {
                      onPaymentTypeChanged(PaymentType.card);
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    key: const Key('paymentTypeContractOption'),
                    title: const Text('По договору'),
                    leading: Text(_paymentIcon(PaymentType.contract)),
                    onTap: () {
                      onPaymentTypeChanged(PaymentType.contract);
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    key: const Key('paymentTypeCashOption'),
                    title: const Text('Наличные'),
                    leading: Text(_paymentIcon(PaymentType.cash)),
                    onTap: () {
                      onPaymentTypeChanged(PaymentType.cash);
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Отмена',
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
