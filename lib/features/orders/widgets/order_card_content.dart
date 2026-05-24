part of 'order_card.dart';

const double _routeActionColumnWidth = 112;

class _CardContent extends StatelessWidget {
  final OrderItem order;
  final int number;
  final bool showRouteButton;
  final bool isNew;

  const _CardContent({
    required this.order,
    required this.number,
    this.showRouteButton = true,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrderCardHeaderRow(order: order, number: number, isNew: isNew),
        const SizedBox(height: 8),
        _OrderCardAddressRow(order: order),
        const SizedBox(height: 6),
        _OrderCardClientRow(order: order),
        _OrderCardCommentRow(order: order),
        const SizedBox(height: 10),
        _OrderCardFooterRow(order: order, showRouteButton: showRouteButton),
      ],
    );
  }
}
