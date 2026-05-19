part of '../order_detail_screen.dart';

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
