part of 'home_screen.dart';

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeToggle({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: Colors.white,
        size: 18,
      ),
      tooltip: isDark ? 'Темная тема' : 'Светлая тема',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        fixedSize: const Size(34, 34),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _LowDataToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _LowDataToggle({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.signal_cellular_alt_1_bar : Icons.speed_rounded,
              color: enabled ? AppColors.liveGreen : Colors.white,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              enabled ? '2G' : '2G',
              style: TextStyle(
                color: enabled ? AppColors.liveGreen : Colors.white,
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
