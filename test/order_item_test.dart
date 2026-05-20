import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and restores delivery details', () {
    const order = OrderItem(
      id: '#1',
      clientName: 'Тестовый клиент',
      address: 'ул. Тестовая, 1',
      district: 'Анапа',
      price: 560,
      payment: PaymentType.qr,
      bottles: 2,
      lat: 44.8951,
      lng: 37.3168,
      isDone: true,
      deliveryState: OrderDeliveryState.delivered,
      deliveredBottles: 2,
      returnedBottles: 1,
      confirmedPayment: PaymentType.online,
      extras: {'Помпа': 1},
      scannedItems: {'water': 2},
      deliveryComment: 'Оставлено у двери',
    );

    final restored = OrderItem.fromJson(order.toJson());

    expect(restored.id, order.id);
    expect(restored.displayId, order.id);
    expect(restored.payment, PaymentType.qr);
    expect(restored.effectiveDeliveryState, OrderDeliveryState.delivered);
    expect(restored.confirmedPayment, PaymentType.online);
    expect(restored.extras, {'Помпа': 1});
    expect(restored.scannedItems, {'water': 2});
    expect(restored.deliveryComment, 'Оставлено у двери');
  });
  test('copyWith can update and clear nullable fields', () {
    const order = OrderItem(
      id: '#1',
      clientName: 'Client',
      address: 'Address',
      district: 'District',
      price: 560,
      payment: PaymentType.cash,
      bottles: 2,
      lat: 44.8951,
      lng: 37.3168,
      comment: 'Old comment',
      phone: '+79990000000',
      deliveredBottles: 1,
      returnedBottles: 1,
      confirmedPayment: PaymentType.cash,
      deliveryComment: 'Left at door',
      failureReason: 'No answer',
    );

    final updated = order.copyWith(
      comment: 'New comment',
      phone: '+78880000000',
      deliveredBottles: null,
      returnedBottles: null,
      confirmedPayment: null,
      deliveryComment: null,
      failureReason: null,
    );

    expect(updated.comment, 'New comment');
    expect(updated.phone, '+78880000000');
    expect(updated.deliveredBottles, isNull);
    expect(updated.returnedBottles, isNull);
    expect(updated.confirmedPayment, isNull);
    expect(updated.deliveryComment, isNull);
    expect(updated.failureReason, isNull);
  });

  test('uses order number for display while keeping backend id', () {
    const order = OrderItem(
      id: '7ee65d46-1a38-4eb1-9d21-b491c61e04544',
      orderNumber: '#4821',
      clientName: 'Client',
      address: 'Address',
      district: 'District',
      price: 400,
      payment: PaymentType.cash,
      bottles: 1,
      lat: 44.8951,
      lng: 37.3168,
    );

    final restored = OrderItem.fromJson(order.toJson());

    expect(restored.id, '7ee65d46-1a38-4eb1-9d21-b491c61e04544');
    expect(restored.orderNumber, '#4821');
    expect(restored.displayId, '#4821');
  });

  test('maps backend order rows to app model', () {
    final order = OrderItem.fromBackendJson({
      'id': '7ee65d46-1a38-4eb1-9d21-b491c61e04544',
      'order_number': '#4821',
      'client_name': 'Client',
      'client_phone': '+79990000000',
      'address': 'Address',
      'district': 'District',
      'lat': 44.8951,
      'lng': 37.3168,
      'payment_method': 'qr',
      'price': 900,
      'bottles': 3,
      'state': 'delivered',
      'extras': {'pump': 1},
      'scanned_items': {'water': 3},
      'delivered_bottles': 3,
      'returned_bottles': 0,
      'confirmed_payment': 'online',
      'delivery_comment': 'Done',
      'failure_reason': null,
    });

    expect(order.id, '7ee65d46-1a38-4eb1-9d21-b491c61e04544');
    expect(order.displayId, '#4821');
    expect(order.payment, PaymentType.qr);
    expect(order.effectiveDeliveryState, OrderDeliveryState.delivered);
    expect(order.confirmedPayment, PaymentType.online);
    expect(order.extras, {'pump': 1});
    expect(order.scannedItems, {'water': 3});
  });
}
