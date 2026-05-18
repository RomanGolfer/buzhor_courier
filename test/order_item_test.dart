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
}
