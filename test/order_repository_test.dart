import 'package:buzhor_courier/features/orders/data/order_action_journal.dart';
import 'package:buzhor_courier/features/orders/data/order_backend_api.dart';
import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
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
  test('restores saved orders from local storage', () async {
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
      markingCodes: const {
        'water': ['010460123456789021A1', '010460123456789021A2'],
      },
      clientRating: const ClientRating(rating: 2),
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

  test('replays unfinished local action journal', () async {
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
      markingCodes: const {
        'water': ['010460123456789021A1', '010460123456789021A2'],
      },
      clientRating: const ClientRating(rating: 2),
    );

    final operation = storage.savedSyncOperations.single;
    expect(operation.type, OrderSyncOperationType.complete);
    expect(operation.status, OrderSyncOperationStatus.pending);
    expect(operation.orderId, _activeOrder.id);
    expect(operation.payload['bottles'], 2);
    expect(operation.payload['paymentType'], PaymentType.cash.name);
    expect(operation.payload['markingCodes'], {
      'water': ['010460123456789021A1', '010460123456789021A2'],
    });
    final fiscalReceipt =
        operation.payload['fiscalReceipt'] as Map<String, dynamic>;
    expect(fiscalReceipt['status'], 'pending');
    expect(fiscalReceipt['operationId'], startsWith('fiscal-#1-'));
    final clientRating =
        operation.payload['clientRating'] as Map<String, dynamic>;
    expect(clientRating['rating'], 2);
  });

  test(
    'completeOrder does not require fiscal receipt for contract payment',
    () async {
      final repository = OrderRepository(initialOrders: [_activeOrder]);

      final orders = await repository.completeOrder(
        _activeOrder.id,
        bottles: 2,
        returnedBottles: 0,
        paymentType: PaymentType.contract,
        extras: const {},
        scannedItems: const {},
      );

      expect(
        orders.single.fiscalReceipt.status,
        FiscalReceiptStatus.notRequired,
      );
    },
  );

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

  test('prefers backend orders and caches them locally', () async {
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

  test(
    'stale active realtime update does not reopen locally completed order',
    () async {
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
      final afterRealtime = await repository.upsertOrder(
        _activeOrder.copyWith(comment: 'stale'),
      );

      expect(
        afterRealtime.single.effectiveDeliveryState,
        OrderDeliveryState.delivered,
      );
      expect(afterRealtime.single.comment, isNull);
    },
  );
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
