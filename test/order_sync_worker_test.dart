import 'package:buzhor_courier/features/orders/data/order_action_journal.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_worker.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync marks pending operation as acked after dispatch', () async {
    final operation = OrderSyncOperation.fail('#1', reason: 'No answer');
    final storage = _FakeOrderStorage(syncOperations: [operation]);
    final dispatcher = _FakeOrderSyncDispatcher();
    final worker = OrderSyncWorker(storage: storage, dispatcher: dispatcher);

    await worker.sync();

    expect(dispatcher.dispatched.single.operationId, operation.operationId);
    expect(
      storage.savedSyncOperations.single.status,
      OrderSyncOperationStatus.acked,
    );
    expect(storage.savedSyncOperations.single.ackedAt, isNotNull);
  });

  test('sync schedules retry after dispatch failure', () async {
    final operation = OrderSyncOperation.fail('#1', reason: 'No answer');
    final storage = _FakeOrderStorage(syncOperations: [operation]);
    final dispatcher = _FakeOrderSyncDispatcher(error: Exception('offline'));
    final worker = OrderSyncWorker(storage: storage, dispatcher: dispatcher);

    await worker.sync();

    final saved = storage.savedSyncOperations.single;
    expect(saved.status, OrderSyncOperationStatus.pending);
    expect(saved.attemptCount, 1);
    expect(saved.nextAttemptAt, isNotNull);
    expect(saved.lastError, contains('offline'));
  });

  test('sync does nothing without backend session', () async {
    final operation = OrderSyncOperation.fail('#1', reason: 'No answer');
    final storage = _FakeOrderStorage(syncOperations: [operation]);
    final dispatcher = _FakeOrderSyncDispatcher(canSync: false);
    final worker = OrderSyncWorker(storage: storage, dispatcher: dispatcher);

    await worker.sync();

    expect(dispatcher.dispatched, isEmpty);
    expect(
      storage.savedSyncOperations.single.status,
      OrderSyncOperationStatus.pending,
    );
  });
}

class _FakeOrderSyncDispatcher implements OrderSyncDispatcher {
  final bool _canSync;
  final Object? error;
  final List<OrderSyncOperation> dispatched = [];

  _FakeOrderSyncDispatcher({bool canSync = true, this.error})
    : _canSync = canSync;

  @override
  bool get canSync => _canSync;

  @override
  Future<void> dispatch(OrderSyncOperation operation) async {
    if (error != null) throw error!;
    dispatched.add(operation);
  }
}

class _FakeOrderStorage implements OrderStorage {
  _FakeOrderStorage({List<OrderSyncOperation>? syncOperations})
    : savedSyncOperations = List<OrderSyncOperation>.of(
        syncOperations ?? const [],
      );

  final List<OrderSyncOperation> savedSyncOperations;

  @override
  Future<List<OrderItem>?> loadOrders() async => null;

  @override
  Future<void> saveOrders(List<OrderItem> orders) async {}

  @override
  Future<List<OrderActionJournalEntry>> loadActionJournal() async => const [];

  @override
  Future<void> appendActionJournalEntry(OrderActionJournalEntry entry) async {}

  @override
  Future<void> clearActionJournal() async {}

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
