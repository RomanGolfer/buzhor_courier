part of '../route_screen.dart';

class _MapBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _MapBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _LowDataModeChip extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _LowDataModeChip({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? AppColors.darkBlue : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? AppColors.darkBlue
                : AppColors.grayBlue.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.signal_cellular_alt_1_bar : Icons.speed_rounded,
              size: 16,
              color: enabled ? Colors.white : AppColors.darkBlue,
            ),
            const SizedBox(width: 6),
            Text(
              enabled ? '2G включён' : '2G',
              style: TextStyle(
                color: enabled ? Colors.white : AppColors.darkBlue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Address search sheet ─────────────────────────────────────────────────────
