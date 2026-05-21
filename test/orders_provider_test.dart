import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/data/order_action_journal.dart';
import 'package:buzhor_courier/features/orders/data/order_backend_api.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
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
    );
    await notifier.refreshOrders();

    expect(notifier.state.activeOrders, isEmpty);
    expect(notifier.state.completedOrders, hasLength(1));
    expect(
      notifier.state.completedOrders.single.effectiveDeliveryState,
      OrderDeliveryState.delivered,
    );
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

  test('repository restores saved orders from local storage', () async {
    final storage = _FakeOrderStorage();
    final repository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
    );

    await repository.completeOrder(
      _activeOrder.id,
      bottles: 2,
      returnedBottles: 0,
      paymentType: PaymentType.cash,
      extras: const {},
      scannedItems: const {'water': 2},
    );

    final restoredRepository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
    );
    final restored = await restoredRepository.fetchOrders();

    expect(
      restored.single.effectiveDeliveryState,
      OrderDeliveryState.delivered,
    );
    expect(restored.single.scannedItems, {'water': 2});
  });

  test('repository replays unfinished local action journal', () async {
    final storage = _FakeOrderStorage();
    await storage.appendActionJournalEntry(
      OrderActionJournalEntry.complete(
        _activeOrder.id,
        bottles: 2,
        returnedBottles: 0,
        paymentType: PaymentType.cash,
        extras: const {},
        scannedItems: const {'water': 2},
      ),
    );

    final repository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
    );

    final restored = await repository.fetchOrders();

    expect(
      restored.single.effectiveDeliveryState,
      OrderDeliveryState.delivered,
    );
    expect(restored.single.scannedItems, {'water': 2});
    expect(storage.savedActionJournal, isEmpty);
  });

  test('completeOrder stores pending sync operation', () async {
    final storage = _FakeOrderStorage();
    final repository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
    );

    await repository.completeOrder(
      _activeOrder.id,
      bottles: 2,
      returnedBottles: 0,
      paymentType: PaymentType.cash,
      extras: const {},
      scannedItems: const {'water': 2},
    );

    final operation = storage.savedSyncOperations.single;
    expect(operation.type, OrderSyncOperationType.complete);
    expect(operation.status, OrderSyncOperationStatus.pending);
    expect(operation.orderId, _activeOrder.id);
    expect(operation.payload['bottles'], 2);
    expect(operation.payload['paymentType'], PaymentType.cash.name);
  });

  test('failOrder stores pending sync operation for nonblank reason', () async {
    final storage = _FakeOrderStorage();
    final repository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
    );

    await repository.failOrder(_activeOrder.id, reason: ' No answer ');

    final operation = storage.savedSyncOperations.single;
    expect(operation.type, OrderSyncOperationType.fail);
    expect(operation.status, OrderSyncOperationStatus.pending);
    expect(operation.orderId, _activeOrder.id);
    expect(operation.payload['reason'], 'No answer');
  });

  test('failOrder does not queue blank reason', () async {
    final storage = _FakeOrderStorage();
    final repository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
    );

    await repository.failOrder(_activeOrder.id, reason: '   ');

    expect(storage.savedSyncOperations, isEmpty);
  });

  test('repository prefers backend orders and caches them locally', () async {
    final storage = _FakeOrderStorage();
    final backendOrder = _incomingOrder.copyWith(orderNumber: '#4822');
    final repository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
      backendApi: _FakeOrderBackendApi([backendOrder]),
    );

    final orders = await repository.fetchOrders();

    expect(orders.single.id, _incomingOrder.id);
    expect(orders.single.displayId, '#4822');
    expect(storage.savedOrders?.single.id, _incomingOrder.id);
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
}

class _FakeOrderBackendApi implements OrderBackendApi {
  final List<OrderItem>? orders;

  const _FakeOrderBackendApi(this.orders);

  @override
  Future<List<OrderItem>?> fetchAssignedOrders() async {
    return orders == null ? null : List<OrderItem>.of(orders!);
  }
}

class _FakeOrderStorage implements OrderStorage {
  List<OrderItem>? savedOrders;
  final List<OrderActionJournalEntry> savedActionJournal = [];
  final List<OrderSyncOperation> savedSyncOperations = [];

  @override
  Future<List<OrderItem>?> loadOrders() async {
    return savedOrders == null ? null : List<OrderItem>.of(savedOrders!);
  }

  @override
  Future<void> saveOrders(List<OrderItem> orders) async {
    savedOrders = List<OrderItem>.of(orders);
  }

  @override
  Future<List<OrderActionJournalEntry>> loadActionJournal() async {
    return List<OrderActionJournalEntry>.of(savedActionJournal);
  }

  @override
  Future<void> appendActionJournalEntry(OrderActionJournalEntry entry) async {
    savedActionJournal.add(entry);
  }

  @override
  Future<void> clearActionJournal() async {
    savedActionJournal.clear();
  }

  @override
  Future<List<OrderSyncOperation>> loadSyncOperations() async {
    return List<OrderSyncOperation>.of(savedSyncOperations);
  }

  @override
  Future<void> appendSyncOperation(OrderSyncOperation operation) async {
    savedSyncOperations.add(operation);
  }

  @override
  Future<void> saveSyncOperations(List<OrderSyncOperation> operations) async {
    savedSyncOperations
      ..clear()
      ..addAll(operations);
  }
}
