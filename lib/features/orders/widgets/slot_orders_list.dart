part of 'slot_header.dart';

class _SlotOrdersList extends StatelessWidget {
  final TimeSlot slot;
  final Set<String> newOrderIds;
  final ValueChanged<String> onOrderOpen;

  const _SlotOrdersList({
    required this.slot,
    required this.newOrderIds,
    required this.onOrderOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(slot.orders.length, (i) {
        final order = slot.orders[i];
        return OrderCard(
          order: order,
          number: i + 1,
          isNew: newOrderIds.contains(order.id),
          onTap: () {
            onOrderOpen(order.id);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: order),
              ),
            );
          },
        );
      }),
    );
  }
}
