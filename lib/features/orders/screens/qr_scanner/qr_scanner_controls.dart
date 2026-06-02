part of '../qr_scanner_screen.dart';

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
