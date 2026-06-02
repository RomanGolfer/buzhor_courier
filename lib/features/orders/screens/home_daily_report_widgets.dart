part of 'home_screen.dart';

class _ReportFilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReportFilterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          Icons.schedule_rounded,
          color: AppColors.textSecondary(context),
          size: 22,
        ),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary(context),
          side: BorderSide(color: AppColors.dividerColor(context), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final String? trailing;
  final List<_ReportRowData> rows;
  final bool titleTappable;
  final bool showDivider;

  const _ReportSection({
    super.key,
    required this.title,
    required this.rows,
    this.trailing,
    this.titleTappable = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              )
            else if (titleTappable)
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textPrimary(context),
                size: 30,
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final row in rows) _ReportRow(row: row),
        if (showDivider) ...[
          const SizedBox(height: 18),
          Divider(color: AppColors.dividerColor(context), thickness: 1.2),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _ReportRowData {
  final String label;
  final num value;
  final bool tappable;

  const _ReportRowData(this.label, this.value, {this.tappable = false});
}

class _ReportRow extends StatelessWidget {
  final _ReportRowData row;

  const _ReportRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            row.value.toInt().toString(),
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (row.tappable) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary(context),
              size: 26,
            ),
          ],
        ],
      ),
    );
  }
}
