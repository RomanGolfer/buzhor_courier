part of '../order_detail_screen.dart';

class _DeliverySummary extends StatelessWidget {
  final int bottles;
  final Map<String, int> extras;

  const _DeliverySummary({required this.bottles, required this.extras});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$bottles бут. к доставке',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: extras.entries
                  .map(
                    (entry) => Chip(
                      label: Text('${entry.key} ×${entry.value}'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.lightBlue.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
