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

  test('sync dispatches pending operations oldest first', () async {
    final older = OrderSyncOperation.fail('#1', reason: 'old');
    final newer = OrderSyncOperation.fail('#2', reason: 'new');
    final storage = _FakeOrderStorage(syncOperations: [newer, older]);
    final dispatcher = _FakeOrderSyncDispatcher();
    final worker = OrderSyncWorker(storage: storage, dispatcher: dispatcher);

    await worker.sync();

    expect(dispatcher.dispatched.map((op) => op.orderId), ['#1', '#2']);
  });

  test('sync preserves rejected status from backend', () async {
    final operation = OrderSyncOperation.fail('#1', reason: 'No answer');
    final storage = _FakeOrderStorage(syncOperations: [operation]);
    final dispatcher = _FakeOrderSyncDispatcher(
      result: const OrderSyncDispatchResult(
        status: OrderSyncOperationStatus.rejected,
        lastError: 'order_not_assigned',
      ),
    );
    final worker = OrderSyncWorker(storage: storage, dispatcher: dispatcher);

    await worker.sync();

    final saved = storage.savedSyncOperations.single;
    expect(saved.status, OrderSyncOperationStatus.rejected);
    expect(saved.lastError, 'order_not_assigned');
    expect(saved.ackedAt, isNotNull);
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

  test('sync marks operation as needsReview after max attempts', () async {
    final operation = OrderSyncOperation.fail(
      '#1',
      reason: 'No answer',
    ).copyWith(attemptCount: 4);
    final storage = _FakeOrderStorage(syncOperations: [operation]);
    final dispatcher = _FakeOrderSyncDispatcher(
      error: Exception('network error'),
    );
    final worker = OrderSyncWorker(storage: storage, dispatcher: dispatcher);

    await worker.sync();

    final saved = storage.savedSyncOperations.single;
    expect(saved.status, OrderSyncOperationStatus.needsReview);
    expect(saved.attemptCount, 5);
    expect(saved.lastError, contains('network error'));
  });

  test('sync skips operation whose nextAttemptAt is in the future', () async {
    final operation = OrderSyncOperation.fail(
      '#1',
      reason: 'No answer',
    ).copyWith(nextAttemptAt: DateTime.now().add(const Duration(hours: 1)));
    final storage = _FakeOrderStorage(syncOperations: [operation]);
    final dispatcher = _FakeOrderSyncDispatcher();
    final worker = OrderSyncWorker(storage: storage, dispatcher: dispatcher);

    await worker.sync();

    expect(dispatcher.dispatched, isEmpty);
    expect(storage.savedSyncOperations.single.attemptCount, 0);
  });

  test('sync skips non-pending operations', () async {
    final acked = OrderSyncOperation.fail(
      '#1',
      reason: 'x',
    ).copyWith(status: OrderSyncOperationStatus.acked);
    final needsReview = OrderSyncOperation.fail(
      '#2',
      reason: 'y',
    ).copyWith(status: OrderSyncOperationStatus.needsReview);
    final storage = _FakeOrderStorage(syncOperations: [acked, needsReview]);
    final dispatcher = _FakeOrderSyncDispatcher();
    final worker = OrderSyncWorker(storage: storage, dispatcher: dispatcher);

    await worker.sync();

    expect(dispatcher.dispatched, isEmpty);
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
  final OrderSyncDispatchResult result;
  final List<OrderSyncOperation> dispatched = [];

  _FakeOrderSyncDispatcher({
    bool canSync = true,
    this.error,
    this.result = const OrderSyncDispatchResult.acked(),
  }) : _canSync = canSync;

  @override
  bool get canSync => _canSync;

  @override
  Future<OrderSyncDispatchResult> dispatch(OrderSyncOperation operation) async {
    if (error != null) throw error!;
    dispatched.add(operation);
    return result;
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
