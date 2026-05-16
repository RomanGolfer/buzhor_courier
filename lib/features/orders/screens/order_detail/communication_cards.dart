part of '../order_detail_screen.dart';

class _DispatcherCard extends StatelessWidget {
  final OrderItem order;
  const _DispatcherCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'А',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.liveGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Анна · Диспетчер',
                    style: TextStyle(
                      color: AppColors.darkBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Онлайн',
                    style: TextStyle(
                      color: AppColors.liveGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => NavigationService.callPhoneWithFeedback(
                    context,
                    phone: _dispatcherPhone,
                  ),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.orange, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          color: AppColors.orange,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Позвонить',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => NavigationService.openMessenger(
                    context,
                    phone: _dispatcherPhone,
                    message: 'Заказ ${order.id}',
                  ),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Написать',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick SMS card ───────────────────────────────────────────────────────────

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
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    msg,
                    style: const TextStyle(
                      color: AppColors.darkBlue,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.06),
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
            title: const Text(
              '💬 Сообщить клиенту',
              style: TextStyle(
                color: AppColors.darkBlue,
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

// ─── Client card ──────────────────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  final OrderItem order;
  const _ClientCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final phone = order.phone;
    return _SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.clientName,
                    style: const TextStyle(
                      color: AppColors.darkBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (phone != null)
                    Text(
                      phone,
                      style: const TextStyle(
                        color: AppColors.grayBlue,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (phone != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => NavigationService.callPhoneWithFeedback(
                context,
                phone: phone,
              ),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.orange, AppColors.orangeLight],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Позвонить клиенту',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Order items card ─────────────────────────────────────────────────────────
