import 'package:buzhor_courier/features/orders/models/order_item.dart';

class TimeSlot {
  final String label;
  final List<OrderItem> orders;
  final bool isExpanded;

  const TimeSlot({
    required this.label,
    required this.orders,
    this.isExpanded = true,
  });

  TimeSlot copyWith({bool? isExpanded}) {
    return TimeSlot(
      label: label,
      orders: orders,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}
