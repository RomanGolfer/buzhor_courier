part of 'orders_provider.dart';

const _defaultSlotLabel = '10:00 - 14:00';
const _knownSlotLabels = [_defaultSlotLabel, '14:00 - 18:00', '18:00 - 21:00'];

List<TimeSlot> _buildTimeSlots(List<OrderItem> activeOrders) {
  final groupedOrders = <String, List<OrderItem>>{
    for (final label in _knownSlotLabels) label: <OrderItem>[],
  };

  final sortedOrders = List<OrderItem>.of(activeOrders)
    ..sort((a, b) {
      final dateCompare = _deliveryDateKeyFor(
        a,
      ).compareTo(_deliveryDateKeyFor(b));
      if (dateCompare != 0) return dateCompare;
      return _slotSortIndex(
        _slotLabelFor(a),
      ).compareTo(_slotSortIndex(_slotLabelFor(b)));
    });

  for (final order in sortedOrders) {
    final label = _slotLabelFor(order);
    groupedOrders.putIfAbsent(label, () => <OrderItem>[]).add(order);
  }

  final slots = <TimeSlot>[];

  for (final label in _knownSlotLabels) {
    final orders = groupedOrders[label] ?? const <OrderItem>[];
    if (orders.isNotEmpty) {
      slots.add(TimeSlot(label: label, orders: orders));
    }
  }

  for (final entry in groupedOrders.entries) {
    if (_knownSlotLabels.contains(entry.key) || entry.value.isEmpty) {
      continue;
    }
    slots.add(TimeSlot(label: entry.key, orders: entry.value));
  }

  return slots;
}

String _slotLabelFor(OrderItem order) {
  final slot = _baseSlotLabelFor(order);
  final deliveryDate = order.deliveryDate;
  if (deliveryDate == null || _isMoscowToday(deliveryDate)) return slot;
  return '${deliveryDate.day.toString().padLeft(2, '0')}.'
      '${deliveryDate.month.toString().padLeft(2, '0')} · $slot';
}

String _baseSlotLabelFor(OrderItem order) {
  final label = order.timeSlot?.trim();
  if (label == null || label.isEmpty) return _defaultSlotLabel;
  return label;
}

int _slotSortIndex(String label) {
  final baseLabel = label.contains(' · ') ? label.split(' · ').last : label;
  final index = _knownSlotLabels.indexOf(baseLabel);
  return index == -1 ? _knownSlotLabels.length : index;
}

String _deliveryDateKeyFor(OrderItem order) {
  final date = order.deliveryDate;
  if (date == null) return _todayMoscowKey();
  return _dateKey(date);
}

bool _isCurrentOrFutureDeliveryOrder(OrderItem order) {
  final deliveryDate = order.deliveryDate;
  if (deliveryDate == null) return true;
  return _dateKey(deliveryDate).compareTo(_todayMoscowKey()) >= 0;
}

bool _isClosedOrderInCurrentMoscowDay(OrderItem order) {
  final deliveryDate = order.deliveryDate;
  if (deliveryDate != null) return _isMoscowToday(deliveryDate);

  final closedAt = order.updatedAt ?? order.createdAt;
  if (closedAt == null) return false;
  return _dateKey(closedAt.toUtc().add(const Duration(hours: 3))) ==
      _todayMoscowKey();
}

bool _isMoscowToday(DateTime date) => _dateKey(date) == _todayMoscowKey();

String _todayMoscowKey() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 3));
  return _dateKey(now);
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
