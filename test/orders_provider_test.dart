import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const _activeOrder = OrderItem(
  id: '#1',
  clientName: 'Тестовый клиент',
  address: 'ул. Тестовая, 1',
  district: 'Анапа',
  price: 560,
  payment: PaymentType.cash,
  bottles: 2,
  lat: 44.8951,
  lng: 37.3168,
);

const _incomingOrder = OrderItem(
  id: '#2',
  clientName: 'Новый клиент',
  address: 'ул. Новая, 2',
  district: 'Анапа',
  price: 840,
  payment: PaymentType.cash,
  bottles: 3,
  lat: 44.9021,
  lng: 37.3378,
);

const _secondIncomingOrder = OrderItem(
  id: '#3',
  clientName: 'Second incoming client',
  address: 'Second incoming address',
  district: 'Anapa',
  price: 1120,
  payment: PaymentType.card,
  bottles: 4,
  lat: 44.9121,
  lng: 37.3478,
);

void main() {
  test(
    'completeOrder moves active order to completed with delivery details',
    () async {
      final notifier = OrdersNotifier(
        OrderRepository(initialOrders: [_activeOrder]),
      );
      await Future<void>.delayed(Duration.zero);

      await notifier.completeOrder(
        _activeOrder.id,
        bottles: 3,
        returnedBottles: 1,
        paymentType: PaymentType.card,
        extras: {'Помпа': 1},
        scannedItems: {'water': 3},
        markingCodes: {
          'water': [
            '010460123456789021A1',
            '010460123456789021A2',
            '010460123456789021A3',
          ],
        },
        clientRating: const ClientRating(rating: 4),
        comment: 'Оставлено у двери',
      );

      expect(notifier.state.activeOrders, isEmpty);
      expect(notifier.state.timeSlots, isEmpty);
      expect(notifier.state.completedOrders, hasLength(1));

      final completed = notifier.state.completedOrders.single;
      expect(completed.effectiveDeliveryState, OrderDeliveryState.delivered);
      expect(completed.deliveredBottles, 3);
      expect(completed.returnedBottles, 1);
      expect(completed.confirmedPayment, PaymentType.card);
      expect(completed.extras, {'Помпа': 1});
      expect(completed.scannedItems, {'water': 3});
      expect(completed.markingCodes['water'], hasLength(3));
      expect(completed.fiscalReceipt.status, FiscalReceiptStatus.pending);
      expect(completed.fiscalReceipt.operationId, startsWith('fiscal-#1-'));
      expect(completed.clientRating?.rating, 4);
      expect(completed.deliveryComment, 'Оставлено у двери');
    },
  );

  test(
    'failOrder moves active order to completed with failure reason',
    () async {
      final notifier = OrdersNotifier(
        OrderRepository(initialOrders: [_activeOrder]),
      );
      await Future<void>.delayed(Duration.zero);

      await notifier.failOrder(_activeOrder.id, reason: 'Клиент не отвечает');

      expect(notifier.state.activeOrders, isEmpty);
      expect(notifier.state.completedOrders, hasLength(1));

      final failed = notifier.state.completedOrders.single;
      expect(failed.effectiveDeliveryState, OrderDeliveryState.failed);
      expect(failed.isFailed, isTrue);
      expect(failed.failureReason, 'Клиент не отвечает');
    },
  );

  test('failOrder ignores blank reasons', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.failOrder(_activeOrder.id, reason: '   ');

    expect(notifier.state.activeOrders.single.id, _activeOrder.id);
    expect(
      notifier.state.activeOrders.single.effectiveDeliveryState,
      OrderDeliveryState.active,
    );
    expect(notifier.state.completedOrders, isEmpty);
  });

  test('refreshOrders keeps repository mutations', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.completeOrder(
      _activeOrder.id,
      bottles: 2,
      returnedBottles: 0,
      paymentType: PaymentType.cash,
      extras: const {},
      scannedItems: const {'water': 2},
      markingCodes: const {
        'water': ['010460123456789021A1', '010460123456789021A2'],
      },
      clientRating: const ClientRating(rating: 2),
    );
    await notifier.refreshOrders();

    expect(notifier.state.activeOrders, isEmpty);
    expect(notifier.state.completedOrders, hasLength(1));
    expect(
      notifier.state.completedOrders.single.effectiveDeliveryState,
      OrderDeliveryState.delivered,
    );
  });

  test('refreshOrders reloads orders even when pending sync fails', () async {
    final repository = _ReloadingOrderRepository();
    final notifier = OrdersNotifier(
      repository,
      syncPendingActions: () => throw Exception('sync storage failed'),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.refreshOrders();

    expect(repository.reloadCount, 1);
    expect(notifier.state.activeOrders.map((order) => order.id), [
      _incomingOrder.id,
    ]);
    expect(notifier.state.isLoading, isFalse);
  });

  test('toggleLowDataMode switches global low data mode', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isLowDataMode, isFalse);

    notifier.toggleLowDataMode();
    expect(notifier.state.isLowDataMode, isTrue);

    notifier.toggleLowDataMode();
    expect(notifier.state.isLowDataMode, isFalse);
  });

  test('upsertIncomingOrder adds new pushed order', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.upsertIncomingOrder(_incomingOrder);

    expect(notifier.state.activeOrders.map((order) => order.id), [
      _activeOrder.id,
      _incomingOrder.id,
    ]);
  });

  test('upsertIncomingOrder marks unseen active order as new', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.upsertIncomingOrder(_incomingOrder);

    expect(notifier.state.newOrderIds, {_incomingOrder.id});
  });

  test('markOrderSeen clears one new order marker', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.upsertIncomingOrder(_incomingOrder);
    notifier.markOrderSeen(_incomingOrder.id);

    expect(notifier.state.newOrderIds, isEmpty);
  });

  test('markOrdersSeen clears new markers for a route group', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.upsertIncomingOrder(_incomingOrder);
    await notifier.upsertIncomingOrder(_secondIncomingOrder);
    notifier.markOrdersSeen([_incomingOrder.id, _secondIncomingOrder.id]);

    expect(notifier.state.newOrderIds, isEmpty);
  });

  test('groups active orders by backend time slot', () async {
    final afternoonOrder = _incomingOrder.copyWith(timeSlot: '14:00 - 18:00');
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [afternoonOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.timeSlots, hasLength(1));
    expect(notifier.state.timeSlots.single.label, '14:00 - 18:00');
    expect(notifier.state.timeSlots.single.orders.single.id, afternoonOrder.id);
  });

  test('groups future active orders by delivery date and time slot', () async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final futureOrder = _incomingOrder.copyWith(
      deliveryDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      timeSlot: '18:00 - 21:00',
    );
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [futureOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    final expectedDate =
        '${tomorrow.day.toString().padLeft(2, '0')}.'
        '${tomorrow.month.toString().padLeft(2, '0')}';
    expect(notifier.state.timeSlots, hasLength(1));
    expect(
      notifier.state.timeSlots.single.label,
      '$expectedDate · 18:00 - 21:00',
    );
    expect(notifier.state.timeSlots.single.orders.single.id, futureOrder.id);
  });

  test('hides active orders from past delivery dates', () async {
    final yesterday = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 3))
        .subtract(const Duration(days: 1));
    final staleOrder = _incomingOrder.copyWith(
      deliveryDate: DateTime(yesterday.year, yesterday.month, yesterday.day),
    );
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [staleOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.activeOrders, isEmpty);
    expect(notifier.state.timeSlots, isEmpty);
  });

  test('completed orders use delivery date before updated timestamp', () async {
    final nowMoscow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final yesterday = nowMoscow.subtract(const Duration(days: 1));
    final staleCompleted = _incomingOrder.copyWith(
      deliveryDate: DateTime(yesterday.year, yesterday.month, yesterday.day),
      deliveryState: OrderDeliveryState.delivered,
      isDone: true,
      updatedAt: DateTime.now().toUtc(),
    );
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [staleCompleted]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.completedOrders, isEmpty);
  });
}

class _ReloadingOrderRepository extends OrderRepository {
  _ReloadingOrderRepository() : super(initialOrders: const []);

  int reloadCount = 0;

  @override
  Future<List<OrderItem>> reloadOrders() async {
    reloadCount += 1;
    return const [_incomingOrder];
  }
}
