part of '../order_detail_screen.dart';

class _PaymentQrFullScreenControls extends StatelessWidget {
  final double bottomPadding;
  final double buttonHeight;
  final double buttonSpacing;
  final bool isCheckingPayment;
  final bool isSharing;
  final PaymentStatusCheck? paymentCheck;
  final VoidCallback onCheckPayment;
  final VoidCallback onSharePaymentQr;

  const _PaymentQrFullScreenControls({
    required this.bottomPadding,
    required this.buttonHeight,
    required this.buttonSpacing,
    required this.isCheckingPayment,
    required this.isSharing,
    required this.paymentCheck,
    required this.onCheckPayment,
    required this.onSharePaymentQr,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: ElevatedButton.icon(
                onPressed: isCheckingPayment ? null : onCheckPayment,
                icon: Icon(
                  isCheckingPayment
                      ? Icons.hourglass_top_rounded
                      : Icons.verified_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  isCheckingPayment ? 'Проверяем...' : 'Проверить оплату',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  disabledBackgroundColor: AppColors.grayBlueLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            SizedBox(height: buttonSpacing),
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: OutlinedButton.icon(
                onPressed: isSharing ? null : onSharePaymentQr,
                icon: Icon(
                  isSharing ? Icons.hourglass_top_rounded : Icons.share_rounded,
                  size: 20,
                ),
                label: Text(
                  isSharing ? 'Подготовка...' : 'Отправить в мессенджер',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: BorderSide(color: AppColors.blue),
                  disabledForegroundColor: AppColors.grayBlue,
                  disabledBackgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            if (paymentCheck != null) ...[
              SizedBox(height: buttonSpacing),
              _PaymentStatusNotice(check: paymentCheck!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentQrShareCaptureLayer extends StatelessWidget {
  final GlobalKey qrImageKey;
  final OrderItem order;
  final double amount;

  const _PaymentQrShareCaptureLayer({
    required this.qrImageKey,
    required this.order,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    // Positioned off-screen (not Offstage) so Flutter still paints the widget.
    // RepaintBoundary.toImage() needs a rendered object, and the white canvas
    // prevents transparent corners from appearing black in messengers.
    return Positioned(
      left: -9999,
      top: -9999,
      child: RepaintBoundary(
        key: qrImageKey,
        child: ColoredBox(
          color: Colors.white,
          child: SizedBox(
            width: 360,
            child: _PaymentQrShareCard(
              order: order,
              amount: amount,
              qrSize: 300,
            ),
          ),
        ),
      ),
    );
  }
}
