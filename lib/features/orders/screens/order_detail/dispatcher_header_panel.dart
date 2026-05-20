part of '../order_detail_screen.dart';

class _DispatcherHeaderPanel extends StatelessWidget {
  final OrderItem order;
  final String dispatcherPhone;
  final double reveal;
  final VoidCallback onAction;

  const _DispatcherHeaderPanel({
    required this.order,
    required this.dispatcherPhone,
    required this.reveal,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final clampedReveal = reveal.clamp(0.0, 1.0);
    final topOffset = MediaQuery.paddingOf(context).top + 52;

    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: clampedReveal == 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: Offset(0, -0.24 * (1 - clampedReveal)),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: clampedReveal,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface(context).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkBlue.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Анна · Диспетчер',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
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
                          phone: dispatcherPhone,
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
                          phone: dispatcherPhone,
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
