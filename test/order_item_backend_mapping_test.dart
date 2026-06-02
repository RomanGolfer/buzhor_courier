import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      'marking_codes': {
        'water': [
          '010460123456789021A1',
          '010460123456789021A2',
          '010460123456789021A3',
        ],
      },
      'fiscal_receipt': {
        'status': 'pending',
        'operationId': 'fiscal-backend-1',
      },
      'client_rating': {'rating': 4},
      'delivered_bottles': 3,
      'returned_bottles': 0,
      'confirmed_payment': 'online',
      'delivery_comment': 'Done',
      'failure_reason': null,
      'time_slot': '14:00 - 18:00',
      'delivery_date': '2026-05-28',
    });

    expect(order.id, '7ee65d46-1a38-4eb1-9d21-b491c61e04544');
    expect(order.displayId, '#4821');
    expect(order.payment, PaymentType.qr);
    expect(order.effectiveDeliveryState, OrderDeliveryState.delivered);
    expect(order.confirmedPayment, PaymentType.online);
    expect(order.extras, {'pump': 1});
    expect(order.scannedItems, {'water': 3});
    expect(order.markingCodes['water'], hasLength(3));
    expect(order.fiscalReceipt.status, FiscalReceiptStatus.pending);
    expect(order.fiscalReceipt.operationId, 'fiscal-backend-1');
    expect(order.clientRating?.rating, 4);
    expect(order.timeSlot, '14:00 - 18:00');
    expect(order.deliveryDate, DateTime(2026, 5, 28));
  });

  test('maps failed and cancelled backend states to failed delivery state', () {
    for (final state in ['failed', 'cancelled']) {
      final order = OrderItem.fromBackendJson({'id': 'x', 'state': state});
      expect(
        order.deliveryState,
        OrderDeliveryState.failed,
        reason: 'state=$state',
      );
      expect(order.isDone, false, reason: 'state=$state');
    }
  });

  test('maps null and unknown backend state to active', () {
    for (final state in [null, 'unknown', 'new']) {
      final order = OrderItem.fromBackendJson({'id': 'x', 'state': state});
      expect(
        order.deliveryState,
        OrderDeliveryState.active,
        reason: 'state=$state',
      );
      expect(order.isDone, false, reason: 'state=$state');
    }
  });

  test('accepts numeric fields returned as strings', () {
    final order = OrderItem.fromBackendJson({
      'id': 'numeric-strings',
      'price': '400.00',
      'lat': '44.8951000',
      'lng': '37.3168000',
    });

    expect(order.price, 400);
    expect(order.lat, 44.8951);
    expect(order.lng, 37.3168);
  });

  test('uses defaults for missing optional backend fields', () {
    final order = OrderItem.fromBackendJson({'id': 'minimal'});

    expect(order.clientName, '');
    expect(order.address, '');
    expect(order.district, '');
    expect(order.price, 0.0);
    expect(order.bottles, 0);
    expect(order.payment, PaymentType.cash);
    expect(order.extras, isEmpty);
    expect(order.scannedItems, isEmpty);
    expect(order.fiscalReceipt.status, FiscalReceiptStatus.notRequired);
    expect(order.clientRating, isNull);
    expect(order.phone, isNull);
    expect(order.timeSlot, isNull);
    expect(order.deliveryState, OrderDeliveryState.active);
  });
}
