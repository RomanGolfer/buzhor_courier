part of '../route_screen.dart';

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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
