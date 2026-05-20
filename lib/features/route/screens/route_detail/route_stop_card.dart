part of '../route_screen.dart';

class _RouteStopCard extends StatelessWidget {
  final OrderItem order;
  final int number;
  final VoidCallback onTap;

  const _RouteStopCard({
    required this.order,
    required this.number,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: order.isDone
              ? const Color(0xFFF2FBF0)
              : const Color(0xFFF0F5FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: order.isDone
                ? AppColors.green.withValues(alpha: 0.3)
                : AppColors.blue.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: order.isDone ? AppColors.green : AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.displayId,
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order.isDone)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: AppColors.green,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              order.clientName,
              style: const TextStyle(
                color: AppColors.darkBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              order.district,
              style: TextStyle(
                color: AppColors.lightBlue.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${order.bottles} бут.',
                    style: TextStyle(
                      color: const Color(0xFF6B8CAE).withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${order.price.toInt()} ₽',
                  style: TextStyle(
                    color: order.isDone ? AppColors.green : AppColors.darkBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
