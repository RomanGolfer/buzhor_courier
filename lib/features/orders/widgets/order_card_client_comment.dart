part of 'order_card.dart';

class _OrderCardClientRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardClientRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            order.clientName,
            maxLines: 1,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 92),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.isDark(context)
                  ? AppColors.softSurface(context)
                  : const Color(0xFFD6E8F8),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              order.district,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.isDark(context)
                    ? AppColors.grayBlueLight
                    : AppColors.blue,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderCardCommentRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardCommentRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final comment = order.comment;
    if (comment == null || comment.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: AppColors.orange,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
