part of '../route_screen.dart';

class _RouteHeader extends StatelessWidget {
  final List<OrderItem> sortedOrders;
  final LatLng? startPoint;
  final bool isGpsStart;
  final double centerLat;
  final double centerLng;
  final MapController mapController;
  final VoidCallback onBack;
  final VoidCallback onSearch;

  const _RouteHeader({
    required this.sortedOrders,
    required this.startPoint,
    required this.isGpsStart,
    required this.centerLat,
    required this.centerLng,
    required this.mapController,
    required this.onBack,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            _MapBtn(
              onTap: onBack,
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppColors.darkBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, color: AppColors.orange, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        startPoint == null
                            ? '${sortedOrders.length} остановок'
                            : '${isGpsStart ? 'GPS' : 'Своя точка'} · ${sortedOrders.length} остановок',
                        style: const TextStyle(
                          color: AppColors.darkBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _MapBtn(
              onTap: onSearch,
              child: const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.darkBlue,
              ),
            ),
            const SizedBox(width: 8),
            _MapBtn(
              onTap: () => mapController.move(LatLng(centerLat, centerLng), 14.5),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                size: 20,
                color: AppColors.darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared map overlay widgets ───────────────────────────────────────────────

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

class _AddressSearchSheet extends StatefulWidget {
  final bool isSearching;
  final String searchError;
  final void Function(String) onSearch;

  const _AddressSearchSheet({
    required this.isSearching,
    required this.searchError,
    required this.onSearch,
  });

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6E4F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Начальная точка',
              style: TextStyle(
                color: AppColors.darkBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Введите адрес или долгим нажатием на карте',
              style: TextStyle(
                color: const Color(0xFF6B8CAE).withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6E4F0)),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.darkBlue, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'ул. Крымская, 45, Анапа',
                  hintStyle: TextStyle(color: Color(0xFF8AACCC)),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF8AACCC),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                onSubmitted: widget.onSearch,
              ),
            ),
            if (widget.searchError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.searchError,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GestureDetector(
                onTap: () => widget.onSearch(_controller.text),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.blue, AppColors.lightBlue],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.isSearching
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'Найти',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
