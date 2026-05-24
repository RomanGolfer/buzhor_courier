import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class MarkingScanResult {
  final List<String> codes;

  const MarkingScanResult({required this.codes});

  const MarkingScanResult.empty() : codes = const [];

  int get count => codes.length;
}

class QrScannerScreen extends StatefulWidget {
  final String itemName;
  final int requiredCount;

  const QrScannerScreen({
    super.key,
    required this.itemName,
    required this.requiredCount,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  static const double _frameSize = 250;

  final MobileScannerController _controller = MobileScannerController();
  final Set<String> _scannedCodes = {};

  bool _isTorchOn = false;
  bool _isCompleting = false;

  int get _requiredCount => widget.requiredCount.clamp(0, 999);
  int get _scannedCount => _scannedCodes.length;

  @override
  void initState() {
    super.initState();
    if (_requiredCount == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(const MarkingScanResult.empty());
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_isCompleting) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null || code.isEmpty || !_scannedCodes.add(code)) continue;

      HapticFeedback.mediumImpact();
      setState(() {});

      if (_scannedCount >= _requiredCount) {
        _finishAfterDelay();
      }
      return;
    }
  }

  Future<void> _finishAfterDelay() async {
    if (_isCompleting) return;
    _isCompleting = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pop(_scanResult());
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (!mounted) return;
    setState(() => _isTorchOn = !_isTorchOn);
  }

  void _close() {
    Navigator.of(context).pop(_scanResult());
  }

  MarkingScanResult _scanResult() {
    return MarkingScanResult(codes: List.unmodifiable(_scannedCodes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleDetect,
            ),
          ),
          const Positioned.fill(child: _ScannerOverlay(frameSize: _frameSize)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Отсканируйте маркировку',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.itemName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$_scannedCount / $_requiredCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ScannerControlButton(
                      icon: Icons.close_rounded,
                      onTap: _close,
                    ),
                    _ScannerControlButton(
                      icon: _isTorchOn
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      onTap: _toggleTorch,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final double frameSize;

  const _ScannerOverlay({required this.frameSize});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScannerOverlayPainter(frameSize: frameSize));
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double frameSize;

  const _ScannerOverlayPainter({required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );

    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(22)));
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const corner = 34.0;

    final path = Path()
      ..moveTo(frameRect.left, frameRect.top + corner)
      ..lineTo(frameRect.left, frameRect.top)
      ..lineTo(frameRect.left + corner, frameRect.top)
      ..moveTo(frameRect.right - corner, frameRect.top)
      ..lineTo(frameRect.right, frameRect.top)
      ..lineTo(frameRect.right, frameRect.top + corner)
      ..moveTo(frameRect.right, frameRect.bottom - corner)
      ..lineTo(frameRect.right, frameRect.bottom)
      ..lineTo(frameRect.right - corner, frameRect.bottom)
      ..moveTo(frameRect.left + corner, frameRect.bottom)
      ..lineTo(frameRect.left, frameRect.bottom)
      ..lineTo(frameRect.left, frameRect.bottom - corner);
    canvas.drawPath(path, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.frameSize != frameSize;
  }
}

class _ScannerControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScannerControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 30),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        fixedSize: const Size(56, 56),
      ),
    );
  }
}
