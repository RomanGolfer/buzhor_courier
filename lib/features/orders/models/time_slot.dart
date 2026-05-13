import 'package:buzhor_courier/features/orders/models/order_item.dart';

class TimeSlot {
  final String label;
  final List<OrderItem> orders;
  bool isExpanded;

  TimeSlot({required this.label, required this.orders, this.isExpanded = true});
}
