part of '../order_detail_screen.dart';

extension _DeliverySheetSections on _DeliverySheetState {
  Widget _buildClientRatingSection() {
    final label = switch (_clientRating) {
      5 => 'отлично',
      4 => 'хорошо',
      3 => 'нормально',
      2 => 'сложно',
      _ => 'проблемно',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Оценка клиента',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.softSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.dividerColor(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (int rating = 1; rating <= 5; rating++)
                      IconButton(
                        key: Key('clientRatingStar$rating'),
                        onPressed: () => _setClientRating(rating),
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: '$rating из 5',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          rating <= _clientRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppColors.orange,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 76),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarkingSection() {
    final scannedCount =
        _markingCodes['water']?.length ?? _scannedItems['water'] ?? 0;
    final isComplete = scannedCount == widget.bottles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Маркировка товаров',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.softSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.dividerColor(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Вода "Бужор" 19л',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$scannedCount / ${widget.bottles} отсканировано',
                      style: const TextStyle(
                        color: AppColors.grayBlue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (scannedCount > 0) ...[
                TextButton(
                  onPressed: _resetWaterScanResult,
                  child: const Text('Сбросить'),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                onPressed: _openWaterScanner,
                tooltip: scannedCount > 0
                    ? 'Пересканировать'
                    : 'Сканировать маркировку',
                icon: Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.qr_code_scanner_rounded,
                  color: isComplete ? AppColors.green : AppColors.blue,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openWaterScanner() async {
    final result = await Navigator.push<MarkingScanResult>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          itemName: 'Вода Бужор 19л',
          requiredCount: widget.bottles,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _setWaterMarkingCodes(result.codes);
  }
}
