import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and restores delivery details', () {
    final order = OrderItem(
      id: '#1',
      clientName: 'Тестовый клиент',
      address: 'ул. Тестовая, 1',
      district: 'Анапа',
      price: 560,
      payment: PaymentType.qr,
      bottles: 2,
      lat: 44.8951,
      lng: 37.3168,
      timeSlot: '14:00 - 18:00',
      isDone: true,
      deliveryState: OrderDeliveryState.delivered,
      deliveredBottles: 2,
      returnedBottles: 1,
      confirmedPayment: PaymentType.online,
      extras: {'Помпа': 1},
      scannedItems: {'water': 2},
      markingCodes: {
        'water': ['010460123456789021A1', '010460123456789021A2'],
      },
      fiscalReceipt: FiscalReceipt.pending(operationId: 'fiscal-#1-1'),
      clientRating: ClientRating(rating: 5),
      deliveryComment: 'Оставлено у двери',
      deliveryDate: DateTime(2026, 5, 27),
    );

    final restored = OrderItem.fromJson(order.toJson());

    expect(restored.id, order.id);
    expect(restored.displayId, order.id);
    expect(restored.payment, PaymentType.qr);
    expect(restored.timeSlot, '14:00 - 18:00');
    expect(restored.effectiveDeliveryState, OrderDeliveryState.delivered);
    expect(restored.confirmedPayment, PaymentType.online);
    expect(restored.extras, {'Помпа': 1});
    expect(restored.scannedItems, {'water': 2});
    expect(restored.markingCodes, {
      'water': ['010460123456789021A1', '010460123456789021A2'],
    });
    expect(restored.scannedCountFor('water'), 2);
    expect(restored.fiscalReceipt.status, FiscalReceiptStatus.pending);
    expect(restored.fiscalReceipt.operationId, 'fiscal-#1-1');
    expect(restored.clientRating?.rating, 5);
    expect(restored.deliveryComment, 'Оставлено у двери');
    expect(restored.deliveryDate, DateTime(2026, 5, 27));
  });
  test('copyWith can update and clear nullable fields', () {
    final order = OrderItem(
      id: '#1',
      clientName: 'Client',
      address: 'Address',
      district: 'District',
      price: 560,
      payment: PaymentType.cash,
      bottles: 2,
      lat: 44.8951,
      lng: 37.3168,
      timeSlot: '10:00 - 14:00',
      comment: 'Old comment',
      phone: '+79990000000',
      deliveredBottles: 1,
      returnedBottles: 1,
      confirmedPayment: PaymentType.cash,
      deliveryComment: 'Left at door',
      failureReason: 'No answer',
      deliveryDate: DateTime(2026, 5, 27),
    );

    final updated = order.copyWith(
      comment: 'New comment',
      phone: '+78880000000',
      deliveredBottles: null,
      returnedBottles: null,
      confirmedPayment: null,
      deliveryComment: null,
      failureReason: null,
      timeSlot: '14:00 - 18:00',
      deliveryDate: null,
    );

    expect(updated.comment, 'New comment');
    expect(updated.phone, '+78880000000');
    expect(updated.deliveredBottles, isNull);
    expect(updated.returnedBottles, isNull);
    expect(updated.confirmedPayment, isNull);
    expect(updated.deliveryComment, isNull);
    expect(updated.failureReason, isNull);
    expect(updated.timeSlot, '14:00 - 18:00');
    expect(updated.deliveryDate, isNull);
  });

  test('copyWith derives scanned item counts from marking codes', () {
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
    );

    final updated = order.copyWith(
      markingCodes: {
        'water': ['010460123456789021A1', '010460123456789021A2'],
      },
    );

    expect(updated.markingCodes['water'], hasLength(2));
    expect(updated.scannedItems, {'water': 2});
    expect(updated.scannedCountFor('water'), 2);
  });

  test('fiscal receipt accepts backend snake case fields', () {
    final receipt = FiscalReceipt.fromJson({
      'status': 'issued',
      'operation_id': 'fiscal-1',
      'receipt_url': 'https://ofd.example/receipt/1',
      'fiscal_document_number': '123',
      'fiscal_drive_number': '456',
      'fiscal_sign': '789',
      'issued_at': '2026-05-24T12:00:00Z',
    });

    expect(receipt.status, FiscalReceiptStatus.issued);
    expect(receipt.operationId, 'fiscal-1');
    expect(receipt.receiptUrl, 'https://ofd.example/receipt/1');
    expect(receipt.fiscalDocumentNumber, '123');
    expect(receipt.fiscalDriveNumber, '456');
    expect(receipt.fiscalSign, '789');
    expect(receipt.issuedAt, DateTime.parse('2026-05-24T12:00:00Z'));
    expect(receipt.toJson()['status'], 'issued');
  });

  test('client rating accepts backend snake case fields', () {
    final rating = ClientRating.fromJson({
      'rating': 4,
      'rated_at': '2026-05-24T12:00:00Z',
    });

    expect(rating?.rating, 4);
    expect(rating?.ratedAt, DateTime.parse('2026-05-24T12:00:00Z'));
    expect(rating?.toJson()['rating'], 4);
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

  test('detects missing and valid coordinates', () {
    const withCoordinates = OrderItem(
      id: '#1',
      clientName: 'Client',
      address: 'Address',
      district: 'District',
      price: 400,
      payment: PaymentType.cash,
      bottles: 1,
      lat: 44.8951,
      lng: 37.3168,
    );
    const withoutCoordinates = OrderItem(
      id: '#2',
      clientName: 'Client',
      address: 'Address',
      district: 'District',
      price: 400,
      payment: PaymentType.cash,
      bottles: 1,
      lat: 0,
      lng: 0,
    );

    expect(withCoordinates.hasCoordinates, isTrue);
    expect(withoutCoordinates.hasCoordinates, isFalse);
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

  test(
    'fromBackendJson maps failed and cancelled state to failed delivery state',
    () {
      for (final state in ['failed', 'cancelled']) {
        final order = OrderItem.fromBackendJson({'id': 'x', 'state': state});
        expect(
          order.deliveryState,
          OrderDeliveryState.failed,
          reason: 'state=$state',
        );
        expect(order.isDone, false, reason: 'state=$state');
      }
    },
  );

  test('fromBackendJson maps null and unknown state to active', () {
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

  test('fromBackendJson uses defaults for missing optional fields', () {
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
