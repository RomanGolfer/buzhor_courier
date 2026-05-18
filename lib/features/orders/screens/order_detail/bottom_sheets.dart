part of '../order_detail_screen.dart';

class _BottomButtons extends StatelessWidget {
  final OrderItem order;
  final int bottles;
  final PaymentType paymentType;
  final Map<String, int> extras;
  final Future<void> Function(_DeliveryConfirmation confirmation) onDelivered;
  final Future<void> Function(_FailureConfirmation confirmation) onFailed;

  const _BottomButtons({
    required this.order,
    required this.bottles,
    required this.paymentType,
    required this.extras,
    required this.onDelivered,
    required this.onFailed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark(context) ? 0.24 : 0.06,
            ),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _FailureSheet(onConfirm: onFailed),
                ),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade400, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Не доставлен',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _DeliverySheet(
                    order: order,
                    bottles: bottles,
                    paymentType: paymentType,
                    extras: extras,
                    onConfirm: onDelivered,
                  ),
                ),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.orange, AppColors.orangeLight],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Доставлен',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Delivery confirmation sheet ──────────────────────────────────────────────

class _DeliverySheet extends StatefulWidget {
  final OrderItem order;
  final int bottles;
  final PaymentType paymentType;
  final Map<String, int> extras;
  final Future<void> Function(_DeliveryConfirmation confirmation) onConfirm;

  const _DeliverySheet({
    required this.order,
    required this.bottles,
    required this.paymentType,
    required this.extras,
    required this.onConfirm,
  });

  @override
  State<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<_DeliverySheet> {
  int _returnedBottles = 0;
  bool _isSubmitting = false;
  final Map<String, int> _scannedItems = {};
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dividerColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Center(child: Text('😊', style: TextStyle(fontSize: 48))),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Заказ доставлен',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _DeliverySummary(bottles: widget.bottles, extras: widget.extras),
              const SizedBox(height: 20),
              _buildMarkingSection(),
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Комментарий к доставке',
                  hintText: 'Необязательно',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.blue,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Возврат бутылей',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CounterButton(
                    icon: Icons.remove,
                    onTap: () => setState(
                      () => _returnedBottles = (_returnedBottles - 1).clamp(
                        0,
                        99,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Center(
                      child: Text(
                        '$_returnedBottles',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  _CounterButton(
                    icon: Icons.add,
                    onTap: () => setState(
                      () => _returnedBottles = (_returnedBottles + 1).clamp(
                        0,
                        99,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Оплата получена',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _buildPaymentSection(widget.paymentType),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _isSubmitting ? null : _submit,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.orange, AppColors.orangeLight],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Подтвердить доставку',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await widget.onConfirm(
      _DeliveryConfirmation(
        returnedBottles: _returnedBottles,
        scannedItems: Map.unmodifiable(_scannedItems),
        comment: _commentController.text,
      ),
    );
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
  }

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
    setState(() => _scannedItems['water'] = result);
  }

  Widget _buildPaymentSection(PaymentType type) {
    switch (type) {
      case PaymentType.card:
        return const _PaymentChip(
          label: 'Картой курьеру ✓',
          color: AppColors.blue,
        );
      case PaymentType.cash:
        return const _PaymentChip(label: 'Наличные ✓', color: AppColors.green);
      case PaymentType.qr:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PaymentChip(label: 'Онлайн оплата ✓', color: AppColors.blue),
            const SizedBox(height: 12),
            _PaymentQrPanel(order: widget.order),
          ],
        );
      case PaymentType.online:
        return const _PaymentChip(label: 'Оплачено ✓', color: AppColors.green);
      case PaymentType.contract:
        return const _PaymentChip(
          label: 'По договору ✓',
          color: AppColors.grayBlue,
        );
    }
  }
}

// ─── Failure reason sheet ─────────────────────────────────────────────────────

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

class _FailureSheet extends StatefulWidget {
  final Future<void> Function(_FailureConfirmation confirmation) onConfirm;

  const _FailureSheet({required this.onConfirm});

  @override
  State<_FailureSheet> createState() => _FailureSheetState();
}

class _FailureSheetState extends State<_FailureSheet> {
  String? _selectedReason;
  bool _isSubmitting = false;
  final _customController = TextEditingController();

  static const _reasons = [
    '🚪 Не открывают дверь',
    '📍 Не могу найти адрес',
    '📞 Клиент не отвечает',
    '❌ Клиент отказался',
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        !_isSubmitting &&
        (_selectedReason != null || _customController.text.trim().isNotEmpty);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Причина недоставки',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((r) {
                final selected = _selectedReason == r;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedReason = selected ? null : r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.red.withValues(alpha: 0.12)
                          : AppColors.softSurface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? Colors.red.shade400
                            : AppColors.dividerColor(context),
                      ),
                    ),
                    child: Text(
                      r,
                      style: TextStyle(
                        color: selected
                            ? Colors.red.shade600
                            : AppColors.textPrimary(context),
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Другая причина...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canConfirm ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade500,
                  disabledBackgroundColor: AppColors.grayBlueLight.withValues(
                    alpha: 0.24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Подтвердить',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final customReason = _customController.text.trim();
    final reason = customReason.isNotEmpty ? customReason : _selectedReason!;
    setState(() => _isSubmitting = true);
    await widget.onConfirm(_FailureConfirmation(reason: reason));
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────
