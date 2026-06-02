part of '../route_screen.dart';

extension _RouteAddressSearchActions on _RouteScreenState {
  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    _updateRouteState(() {
      _isSearching = true;
      _searchError = '';
    });
    try {
      final point = await GeocodingService.searchAddress(query);
      if (point != null && mounted) {
        Navigator.pop(context);
        _setCustomStart(point);
      } else if (mounted) {
        _updateRouteState(() => _searchError = 'Адрес не найден');
      }
    } catch (_) {
      if (mounted) _updateRouteState(() => _searchError = 'Ошибка соединения');
    } finally {
      if (mounted) _updateRouteState(() => _isSearching = false);
    }
  }

  void _showAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressSearchSheet(
        isSearching: _isSearching,
        searchError: _searchError,
        onSearch: _searchAddress,
      ),
    );
  }
}
