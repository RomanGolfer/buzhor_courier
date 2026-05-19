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
              IconButton(
                onPressed: _openWaterScanner,
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

  Widget _buildPaymentQrAction() {
    final isContract = _paymentType == PaymentType.contract;
    final isPaid = _paymentType == PaymentType.online;
    final isQr = _paymentType == PaymentType.qr;
    final title = isQr
        ? 'Открыть QR для оплаты'
        : 'Сгенерировать QR для оплаты';
    final subtitle = isContract
        ? 'Заказ по договору, оплата QR обычно не нужна'
        : isPaid
        ? 'Заказ уже отмечен как оплаченный'
        : '${widget.totalPrice.toInt()} ₽ · заказ ${widget.order.id}';

    return InkWell(
      onTap: isPaid || isContract ? null : _selectQrPaymentAndOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPaid || isContract
              ? AppColors.softSurface(context).withValues(alpha: 0.64)
              : AppColors.blue.withValues(
                  alpha: AppColors.isDark(context) ? 0.18 : 0.10,
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPaid || isContract
                ? AppColors.dividerColor(context)
                : AppColors.blue.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: AppColors.isDark(context) ? 0.10 : 0.82,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                color: isPaid || isContract
                    ? AppColors.textSecondary(context)
                    : AppColors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isPaid || isContract
                          ? AppColors.textSecondary(context)
                          : AppColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_full_rounded,
              color: isPaid || isContract
                  ? AppColors.textSecondary(context)
                  : AppColors.blue,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection(PaymentType type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color fg(PaymentType t) => isDark
        ? switch (t) {
            PaymentType.card => const Color(0xFF8AACCC),
            PaymentType.cash => const Color(0xFF4CAF50),
            PaymentType.qr => const Color(0xFF9C6FD6),
            PaymentType.online => const Color(0xFF26A96C),
            PaymentType.contract => const Color(0xFF888888),
          }
        : switch (t) {
            PaymentType.card => AppColors.blue,
            PaymentType.cash => AppColors.green,
            PaymentType.qr => AppColors.blue,
            PaymentType.online => AppColors.green,
            PaymentType.contract => AppColors.grayBlue,
          };
    Color? bg(PaymentType t) => isDark
        ? switch (t) {
            PaymentType.card => const Color(0xFF2A3A4A),
            PaymentType.cash => const Color(0xFF1A3A1A),
            PaymentType.qr => const Color(0xFF2D1F4A),
            PaymentType.online => const Color(0xFF1A3A2A),
            PaymentType.contract => const Color(0xFF2A2A2A),
          }
        : null;
    switch (type) {
      case PaymentType.card:
        return _PaymentChip(
          label: 'Картой курьеру ✓',
          color: fg(type),
          bgColor: bg(type),
        );
      case PaymentType.cash:
        return _PaymentChip(
          label: 'Наличные ✓',
          color: fg(type),
          bgColor: bg(type),
        );
      case PaymentType.qr:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PaymentChip(
              label: 'Онлайн оплата ✓',
              color: fg(type),
              bgColor: bg(type),
            ),
            const SizedBox(height: 12),
            _PaymentQrPanel(order: widget.order, amount: widget.totalPrice),
          ],
        );
      case PaymentType.online:
        return _PaymentChip(
          label: 'Оплачено ✓',
          color: fg(type),
          bgColor: bg(type),
        );
      case PaymentType.contract:
        return _PaymentChip(
          label: 'По договору ✓',
          color: fg(type),
          bgColor: bg(type),
        );
    }
  }
}
