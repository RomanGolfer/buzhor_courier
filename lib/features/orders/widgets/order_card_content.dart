part of 'order_card.dart';

const double _routeActionColumnWidth = 112;

class _CardContent extends StatelessWidget {
  final OrderItem order;
  final bool showRouteButton;

  const _CardContent({required this.order, this.showRouteButton = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrderCardHeaderRow(order: order),
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
