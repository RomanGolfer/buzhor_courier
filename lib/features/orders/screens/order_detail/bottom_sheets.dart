part of '../order_detail_screen.dart';

class _DeliverySheet extends StatefulWidget {
  final OrderItem order;
  final int bottles;
  final PaymentType paymentType;
  final Map<String, int> extras;
  final Map<String, int> scannedItems;
  final Map<String, List<String>> markingCodes;
  final double totalPrice;
  final ValueChanged<PaymentType> onPaymentTypeChanged;
  final ValueChanged<Map<String, int>> onScannedItemsChanged;
  final ValueChanged<Map<String, List<String>>> onMarkingCodesChanged;
  final Future<void> Function(Map<String, List<String>> expectedMarkingCodes)
  onMarkingCodesReset;
  final Future<OrderItem?> Function() onRefreshOrderBeforeScan;
  final Future<void> Function(_DeliveryConfirmation confirmation) onConfirm;

  const _DeliverySheet({
    required this.order,
    required this.bottles,
    required this.paymentType,
    required this.extras,
    required this.scannedItems,
    required this.markingCodes,
    required this.totalPrice,
    required this.onPaymentTypeChanged,
    required this.onScannedItemsChanged,
    required this.onMarkingCodesChanged,
    required this.onMarkingCodesReset,
    required this.onRefreshOrderBeforeScan,
    required this.onConfirm,
  });

  @override
  State<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<_DeliverySheet> {
  int _returnedBottles = 0;
  int _clientRating = 5;
  bool _isSubmitting = false;
  bool _isResettingMarkingCodes = false;
  final Map<String, int> _scannedItems = {};
  final Map<String, List<String>> _markingCodes = {};
  final _commentController = TextEditingController();
  late PaymentType _paymentType;

  void _setDeliverySheetState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _paymentType = widget.paymentType;
    _returnedBottles = OrderPricingService.defaultReturnedBottles(
      bottles: widget.bottles,
      extras: widget.extras,
    );
    _scannedItems.addAll(widget.scannedItems);
    _markingCodes.addAll(_copyMarkingCodes(widget.markingCodes));
    if (_scannedItems.isEmpty && _markingCodes.isNotEmpty) {
      _scannedItems.addAll(_countsFromMarkingCodes(_markingCodes));
    }
  }

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
              _buildPaymentQrAction(),
              const SizedBox(height: 20),
              _buildClientRatingSection(),
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
              _buildPaymentSection(_paymentType),
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
}
