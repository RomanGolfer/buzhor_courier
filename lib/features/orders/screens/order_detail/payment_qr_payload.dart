part of '../order_detail_screen.dart';

String _paymentQrPayload(OrderItem order, {double? amount}) {
  final paymentAmount = amount ?? order.price;
  return Uri(
    scheme: 'https',
    host: 'pay.buzhor.ru',
    path: '/order',
    queryParameters: {
      'order': order.displayId.replaceAll('#', ''),
      'amount': paymentAmount.toStringAsFixed(2),
    },
  ).toString();
}
