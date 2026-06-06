part of '../order_detail_screen.dart';

void _logPaymentQrShare(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

extension _PaymentQrShareActions on _PaymentQrFullScreenState {
  Future<void> _sharePaymentQr() async {
    if (_isSharing) return;
    _setPaymentQrState(() => _isSharing = true);

    final File? imageFile;
    try {
      imageFile = await _capturePaymentQrImage();
    } catch (e, st) {
      _logPaymentQrShare('QR capture error: $e\n$st');
      if (mounted) {
        _setPaymentQrState(() => _isSharing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Не удалось подготовить QR для отправки'),
            ),
          );
      }
      return;
    }

    if (imageFile == null) {
      _logPaymentQrShare('QR share failed: captured image is null');
      if (mounted) {
        _setPaymentQrState(() => _isSharing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Не удалось подготовить QR для отправки'),
            ),
          );
      }
      return;
    }

    _logPaymentQrShare('QR share: image captured');

    // Navigate back to the orders list before opening the share sheet so that
    // when the courier returns from the messenger, they land on HomeScreen.
    // HomeScreen is route.isFirst because LoginScreen was pushReplacement'd.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Brief pause for the pop animation to settle before the share sheet opens.
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'QR для оплаты заказа ${widget.order.displayId} на сумму ${widget.amount.toInt()} ₽',
          files: [XFile(imageFile.path)],
        ),
      );
      _logPaymentQrShare('QR share: completed successfully');
    } catch (e, st) {
      _logPaymentQrShare('QR share error after navigation: $e\n$st');
      // Widget is already disposed at this point; no UI feedback needed.
    }
  }

  Future<File?> _capturePaymentQrImage() async {
    try {
      // Capture pixel ratio before async operations (avoid using BuildContext across await)
      final pixelRatio = ui
          .PlatformDispatcher
          .instance
          .views
          .first
          .devicePixelRatio
          .clamp(3.0, 4.0);

      // Wait for the next frame to ensure the RepaintBoundary is fully laid out
      await WidgetsBinding.instance.endOfFrame;
      _logPaymentQrShare('QR capture: waited for frame');
      if (!mounted) return null;

      final boundaryContext = _paymentQrImageKey.currentContext;
      if (boundaryContext == null) {
        _logPaymentQrShare('QR capture: boundary context is null');
        return null;
      }
      if (!boundaryContext.mounted) return null;

      final renderObject = boundaryContext.findRenderObject();
      if (renderObject == null) {
        _logPaymentQrShare('QR capture: render object is null');
        return null;
      }

      if (renderObject is! RenderRepaintBoundary) {
        _logPaymentQrShare(
          'QR capture: render object is not RenderRepaintBoundary, got ${renderObject.runtimeType}',
        );
        return null;
      }

      _logPaymentQrShare('QR capture: capturing image');
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      _logPaymentQrShare('QR capture: image captured');

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _logPaymentQrShare('QR capture: byteData is null after toByteData');
        return null;
      }

      final bytes = byteData.buffer.asUint8List();
      _logPaymentQrShare('QR capture: converted to bytes');

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'payment_qr_${widget.order.displayId.replaceAll('#', '')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      _logPaymentQrShare('QR capture: writing image file');

      await file.writeAsBytes(bytes, flush: true);
      _logPaymentQrShare('QR capture: file written successfully');
      return file;
    } catch (e, st) {
      _logPaymentQrShare('QR capture error: $e\n$st');
      return null;
    }
  }
}
