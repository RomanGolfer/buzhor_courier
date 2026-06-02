part of '../qr_scanner_screen.dart';

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
