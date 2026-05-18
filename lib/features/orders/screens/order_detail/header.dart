part of '../order_detail_screen.dart';

class _Header extends StatelessWidget {
  final OrderItem order;
  final VoidCallback? onDispatcherTap;

  const _Header({required this.order, this.onDispatcherTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: isDark
          ? const BoxDecoration(color: Color(0xFF1A1A1A))
          : const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blue, AppColors.darkBlue],
              ),
            ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    order.district,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: onDispatcherTap == null
                    ? const SizedBox(width: 48)
                    : IconButton(
                        tooltip: 'Связаться с диспетчером',
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: onDispatcherTap,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Address card ─────────────────────────────────────────────────────────────
