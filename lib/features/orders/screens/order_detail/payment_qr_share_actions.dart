part of '../order_detail_screen.dart';
import 'package:buzhor_courier/core/logger.dart';

extension _PaymentQrShareActions on _PaymentQrFullScreenState {
  Future<void> _sharePaymentQr() async {
    if (_isSharing) return;
    _setPaymentQrState(() => _isSharing = true);

    final File? imageFile;
    try {
      imageFile = await _capturePaymentQrImage();
    } catch (e, st) {
      logError('QR capture error: $e', error: e, stack: st);
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
      logError('QR share failed: captured image is null');
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

    logDebug('QR share: image ready at ${imageFile.path}');

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
      logDebug('QR share: completed successfully');
    } catch (e, st) {
      logError('QR share error after navigation: $e', error: e, stack: st);
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
      logDebug('QR capture: waited for frame');
      if (!mounted) return null;

      final boundaryContext = _paymentQrImageKey.currentContext;
      if (boundaryContext == null) {
        logError('QR capture: boundary context is null');
        return null;
      }
      if (!boundaryContext.mounted) return null;

      final renderObject = boundaryContext.findRenderObject();
      if (renderObject == null) {
        logError('QR capture: render object is null');
        return null;
      }

      if (renderObject is! RenderRepaintBoundary) {
        logError(
          'QR capture: render object is not RenderRepaintBoundary, got ${renderObject.runtimeType}',
        );
        return null;
      }

      logDebug('QR capture: capturing image with pixelRatio $pixelRatio');
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      logDebug('QR capture: image captured');

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        logError('QR capture: byteData is null after toByteData');
        return null;
      }

      final bytes = byteData.buffer.asUint8List();
      logDebug('QR capture: converted to bytes (${bytes.length} bytes)');

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'payment_qr_${widget.order.displayId.replaceAll('#', '')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      logDebug('QR capture: writing to ${file.path}');

      await file.writeAsBytes(bytes, flush: true);
      logDebug(
        'QR capture: file written successfully (${file.lengthSync()} bytes)',
      );
      return file;
    } catch (e, st) {
      logError('QR capture error: $e', error: e, stack: st);
      return null;
    }
  }
}
