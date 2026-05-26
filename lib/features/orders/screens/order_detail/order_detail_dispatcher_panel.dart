part of '../order_detail_screen.dart';

extension _OrderDetailDispatcherPanel on _OrderDetailScreenState {
  void _toggleDispatcherPanel() {
    if (_dispatcherReveal == 1) {
      _hideDispatcherPanel();
      return;
    }
    _dispatcherHideTimer?.cancel();
    _setOrderDetailState(() => _dispatcherReveal = 1);
    _scheduleDispatcherHide();
  }

  void _scheduleDispatcherHide() {
    _dispatcherHideTimer?.cancel();
    _dispatcherHideTimer = Timer(
      const Duration(seconds: 2),
      _hideDispatcherPanel,
    );
  }

  void _hideDispatcherPanel() {
    _dispatcherHideTimer?.cancel();
    if (!mounted || _dispatcherReveal == 0) return;
    _setOrderDetailState(() => _dispatcherReveal = 0);
  }
}
