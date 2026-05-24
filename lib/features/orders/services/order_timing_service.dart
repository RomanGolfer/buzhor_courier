import 'package:buzhor_courier/features/orders/models/order_item.dart';

class OrderTimingService {
  static const defaultSlotLabel = '10:00 - 14:00';
  static const _moscowOffset = Duration(hours: 3);

  const OrderTimingService._();

  static bool isOverdue(OrderItem order, {DateTime? nowUtc}) {
    if (order.isClosed) return false;

    final slotEnd = _slotEnd(order.timeSlot);
    if (slotEnd == null) return false;

    final nowMoscow = (nowUtc ?? DateTime.now().toUtc()).toUtc().add(
      _moscowOffset,
    );
    final endMoscow = DateTime.utc(
      nowMoscow.year,
      nowMoscow.month,
      nowMoscow.day,
      slotEnd.hour,
      slotEnd.minute,
    );

    return !nowMoscow.isBefore(endMoscow);
  }

  static _SlotTime? _slotEnd(String? rawSlot) {
    final slot = rawSlot?.trim().isNotEmpty == true
        ? rawSlot!.trim()
        : defaultSlotLabel;
    final match = RegExp(
      r'^\s*\d{1,2}:\d{2}\s*[-–—]\s*(\d{1,2}):(\d{2})\s*$',
    ).firstMatch(slot);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return _SlotTime(hour, minute);
  }
}

class _SlotTime {
  final int hour;
  final int minute;

  const _SlotTime(this.hour, this.minute);
}
