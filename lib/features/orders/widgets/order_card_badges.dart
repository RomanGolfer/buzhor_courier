part of 'order_card.dart';

class _NumberBadge extends StatelessWidget {
  final OrderItem order;
  final int number;

  const _NumberBadge({required this.order, required this.number});

  @override
  Widget build(BuildContext context) {
    final color = order.isFailed
        ? Colors.red.shade400
        : order.isClosed
        ? AppColors.green
        : AppColors.orange;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final PaymentType type;
  const _PaymentBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final IconData icon;
    final Color bgColor;
    final Color fgColor;
    final String label;
    switch (type) {
      case PaymentType.card:
        icon = Icons.credit_card_rounded;
        bgColor = isDark
            ? const Color(0xFF2A3A4A)
            : AppColors.blue.withValues(alpha: 0.10);
        fgColor = isDark ? const Color(0xFF8AACCC) : AppColors.blue;
        label = 'Картой';
      case PaymentType.cash:
        icon = Icons.payments_outlined;
        bgColor = isDark
            ? const Color(0xFF1A3A1A)
            : AppColors.green.withValues(alpha: 0.10);
        fgColor = isDark ? const Color(0xFF4CAF50) : AppColors.green;
        label = 'Нал';
      case PaymentType.qr:
        icon = Icons.qr_code_rounded;
        bgColor = isDark
            ? const Color(0xFF2D1F4A)
            : AppColors.purple.withValues(alpha: 0.10);
        fgColor = isDark ? const Color(0xFF9C6FD6) : AppColors.purple;
        label = 'Онлайн';
      case PaymentType.online:
        icon = Icons.contactless;
        bgColor = isDark
            ? const Color(0xFF1A3A2A)
            : AppColors.green.withValues(alpha: 0.10);
        fgColor = isDark ? const Color(0xFF26A96C) : AppColors.green;
        label = 'Оплачено';
      case PaymentType.contract:
        icon = Icons.description_outlined;
        bgColor = isDark
            ? const Color(0xFF2A2A2A)
            : AppColors.grayBlueLight.withValues(alpha: 0.10);
        fgColor = isDark ? const Color(0xFF888888) : AppColors.grayBlueLight;
        label = 'Договор';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
