part of '../order_detail_screen.dart';

class _DispatcherPullPanel extends StatelessWidget {
  final OrderItem order;
  final double reveal;
  final VoidCallback onAction;

  const _DispatcherPullPanel({
    required this.order,
    required this.reveal,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final clampedReveal = reveal.clamp(0.0, 1.0);
    final topOffset = MediaQuery.paddingOf(context).top + 58;

    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: clampedReveal == 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: Offset(0, -0.45 * (1 - clampedReveal)),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: clampedReveal,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkBlue.withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'А',
                              style: TextStyle(
                                color: AppColors.blue,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppColors.liveGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Анна · Диспетчер',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.darkBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Онлайн',
                            style: TextStyle(
                              color: AppColors.liveGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _DispatcherActionButton(
                      icon: Icons.phone_rounded,
                      color: AppColors.orange,
                      onTap: () {
                        onAction();
                        NavigationService.callPhoneWithFeedback(
                          context,
                          phone: _dispatcherPhone,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _DispatcherActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: AppColors.blue,
                      onTap: () {
                        onAction();
                        NavigationService.openMessenger(
                          context,
                          phone: _dispatcherPhone,
                          message: 'Заказ ${order.id}',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DispatcherActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DispatcherActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: color,
        fixedSize: const Size(42, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
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
