part of '../order_detail_screen.dart';

class _QuickSmsCard extends StatelessWidget {
  final OrderItem order;
  const _QuickSmsCard({required this.order});

  static const _messages = [
    '🕐 Буду через 10 мин',
    '🕐 Буду через 20 мин',
    '🕐 Буду через 30 мин',
    '🚪 Доставка у двери',
  ];

  Widget _buildChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _messages
            .map(
              (msg) => GestureDetector(
                onTap: () => NavigationService.sendSmsWithFeedback(
                  context,
                  phone: order.phone,
                  message: msg,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softSurface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.dividerColor(context)),
                  ),
                  child: Text(
                    msg,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark(context)
                ? Colors.black.withValues(alpha: 0.22)
                : AppColors.blue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            childrenPadding: EdgeInsets.zero,
            title: Text(
              '💬 Сообщить клиенту',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(
              Icons.expand_more_rounded,
              color: AppColors.blue,
            ),
            children: [_buildChips(context)],
          ),
        ),
      ),
    );
  }
}
