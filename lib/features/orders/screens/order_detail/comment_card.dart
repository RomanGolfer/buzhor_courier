part of '../order_detail_screen.dart';

class _CommentCard extends StatelessWidget {
  final String comment;
  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              comment,
              style: TextStyle(
                color: AppColors.orange.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom buttons ───────────────────────────────────────────────────────────
