part of '../order_detail_screen.dart';

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
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (phone != null)
                    Text(
                      phone,
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
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
