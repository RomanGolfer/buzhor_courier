part of '../order_detail_screen.dart';

extension _DeliverySheetSections on _DeliverySheetState {
  Widget _buildMarkingSection() {
    final scannedCount = _scannedItems['water'] ?? 0;
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
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          itemName: 'Вода Бужор 19л',
          requiredCount: widget.bottles,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _setWaterScanResult(result);
  }
}
