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
}
