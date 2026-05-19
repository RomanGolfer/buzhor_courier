part of 'slot_header.dart';

class _SlotOrdersList extends StatelessWidget {
  final TimeSlot slot;

  const _SlotOrdersList({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        slot.orders.length,
        (i) => OrderCard(
          order: slot.orders[i],
          number: i + 1,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: slot.orders[i]),
            ),
          ),
        ),
      ),
    );
  }
}
