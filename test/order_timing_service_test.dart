import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/services/order_timing_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _order = OrderItem(
  id: '#1',
  clientName: 'Client',
  address: 'Address',
  district: 'District',
  price: 400,
  payment: PaymentType.cash,
  bottles: 1,
  lat: 44.8951,
  lng: 37.3168,
  timeSlot: '10:00 - 14:00',
);

void main() {
  test('keeps active order normal before Moscow slot end', () {
    final nowUtc = DateTime.utc(2026, 5, 24, 10, 59);

    expect(OrderTimingService.isOverdue(_order, nowUtc: nowUtc), isFalse);
  });

  test('marks active order overdue at Moscow slot end', () {
    final nowUtc = DateTime.utc(2026, 5, 24, 11);

    expect(OrderTimingService.isOverdue(_order, nowUtc: nowUtc), isTrue);
  });

  test('uses default slot when order has no explicit slot', () {
    final nowUtc = DateTime.utc(2026, 5, 24, 11);

    expect(
      OrderTimingService.isOverdue(
        _order.copyWith(timeSlot: null),
        nowUtc: nowUtc,
      ),
      isTrue,
    );
  });

  test('does not mark closed orders overdue', () {
    final nowUtc = DateTime.utc(2026, 5, 24, 12);

    expect(
      OrderTimingService.isOverdue(
        _order.copyWith(deliveryState: OrderDeliveryState.delivered),
        nowUtc: nowUtc,
      ),
      isFalse,
    );
  });
}
