import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/orders/data/order_action_journal.dart';
import 'package:buzhor_courier/features/orders/data/order_backend_api.dart';
import 'package:buzhor_courier/features/orders/data/sample_orders.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/services/order_pricing_service.dart';

part 'order_action_applier.dart';

class OrderRepository {
  OrderRepository({
    List<OrderItem>? initialOrders,
    OrderStorage? storage,
    OrderBackendApi? backendApi,
  }) : _fallbackOrders = List<OrderItem>.of(initialOrders ?? sampleOrders),
       _storage = storage,
       _backendApi = backendApi;

  final List<OrderItem> _fallbackOrders;
  final OrderStorage? _storage;
  final OrderBackendApi? _backendApi;
  final List<OrderItem> _orders = [];
  bool _hasLoaded = false;

  Future<List<OrderItem>> fetchOrders() async {
    await _ensureLoaded();
    return List.unmodifiable(_orders);
  }

  Future<List<OrderItem>> reloadOrders() async {
    _hasLoaded = false;
    return fetchOrders();
  }

  Future<List<OrderItem>> completeOrder(
    String orderId, {
    required int bottles,
    required int returnedBottles,
    required PaymentType paymentType,
    required Map<String, int> extras,
    required Map<String, int> scannedItems,
    Map<String, List<String>> markingCodes = const {},
    ClientRating? clientRating,
    String? comment,
  }) async {
    await _ensureLoaded();
    final currentOrder = _findOrderById(orderId);
    final lockedMarkingCodes = _lockedMarkingCodes(
      currentOrder?.markingCodes ?? const {},
      markingCodes,
    );
    final lockedScannedItems = lockedMarkingCodes.isEmpty
        ? scannedItems
        : _countsFromMarkingCodes(lockedMarkingCodes);
    final fiscalReceipt = _fiscalReceiptForCompletion(orderId, paymentType);
    await _storage?.appendSyncOperation(
      OrderSyncOperation.complete(
        orderId,
        bottles: bottles,
        returnedBottles: returnedBottles,
        paymentType: paymentType,
        extras: extras,
        scannedItems: lockedScannedItems,
        markingCodes: lockedMarkingCodes,
        fiscalReceipt: fiscalReceipt,
        clientRating: clientRating,
        comment: comment,
      ),
    );
    await _commitAction(
      OrderActionJournalEntry.complete(
        orderId,
        bottles: bottles,
        returnedBottles: returnedBottles,
        paymentType: paymentType,
        extras: extras,
        scannedItems: lockedScannedItems,
        markingCodes: lockedMarkingCodes,
        fiscalReceipt: fiscalReceipt,
        clientRating: clientRating,
        comment: comment,
      ),
    );
    return fetchOrders();
  }

  Future<List<OrderItem>> setMarkingCodes(
    String orderId, {
    required Map<String, List<String>> markingCodes,
  }) async {
    await _ensureLoaded();
    final currentOrder = _findOrderById(orderId);
    if (currentOrder == null || currentOrder.isClosed) return fetchOrders();

    final lockedMarkingCodes = _lockedMarkingCodes(
      currentOrder.markingCodes,
      markingCodes,
    );
    if (lockedMarkingCodes.isEmpty) return fetchOrders();

    await _storage?.appendSyncOperation(
      OrderSyncOperation.setMarkingCodes(
        orderId,
        markingCodes: lockedMarkingCodes,
      ),
    );
    await _commitAction(
      OrderActionJournalEntry.setMarkingCodes(
        orderId,
        markingCodes: lockedMarkingCodes,
      ),
    );
    return fetchOrders();
  }

  Future<List<OrderItem>> failOrder(
    String orderId, {
    required String reason,
  }) async {
    await _ensureLoaded();
    final normalizedReason = _normalizeOptionalText(reason);
    if (normalizedReason == null) return fetchOrders();

    await _storage?.appendSyncOperation(
      OrderSyncOperation.fail(orderId, reason: normalizedReason),
    );
    await _commitAction(
      OrderActionJournalEntry.fail(orderId, reason: normalizedReason),
    );
    return fetchOrders();
  }

  Future<List<OrderItem>> upsertOrder(OrderItem incomingOrder) async {
    await _ensureLoaded();
    if (await _shouldKeepLocalOrder(incomingOrder)) return fetchOrders();
    await _commitAction(OrderActionJournalEntry.upsert(incomingOrder));
    return fetchOrders();
  }

  Future<void> _ensureLoaded() async {
    if (_hasLoaded) return;
    final currentOrders = List<OrderItem>.of(_orders);
    final backendOrders = await _backendApi?.fetchAssignedOrders();
    final savedOrders = backendOrders == null
        ? await _storage?.loadOrders()
        : null;
    final orders =
        backendOrders ??
        savedOrders ??
        (currentOrders.isEmpty ? _fallbackOrders : currentOrders);
    _orders
      ..clear()
      ..addAll(orders.map((order) => _normalizePrice(order)));
    if (backendOrders != null) await _persist();
    await _replayActionJournal();
    _hasLoaded = true;
  }

  Future<void> _persist() async {
    await _storage?.saveOrders(List.unmodifiable(_orders));
  }

  Future<void> _commitAction(OrderActionJournalEntry entry) async {
    await _storage?.appendActionJournalEntry(entry);
    _applyAction(entry);
    await _persist();
    await _storage?.clearActionJournal();
  }

  Future<bool> _shouldKeepLocalOrder(OrderItem incomingOrder) async {
    if (!await _hasPendingSyncOperation(incomingOrder.id)) return false;

    final localOrder = _findOrderById(incomingOrder.id);
    return localOrder != null && localOrder.isClosed && !incomingOrder.isClosed;
  }

  OrderItem? _findOrderById(String orderId) {
    for (final order in _orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  Future<bool> _hasPendingSyncOperation(String orderId) async {
    final operations = await _storage?.loadSyncOperations() ?? const [];
    return operations.any((operation) {
      return operation.orderId == orderId &&
          operation.status == OrderSyncOperationStatus.pending;
    });
  }

  Future<void> _replayActionJournal() async {
    final entries = await _storage?.loadActionJournal() ?? const [];
    if (entries.isEmpty) return;

    for (final entry in entries) {
      _applyAction(entry);
    }
    await _persist();
    await _storage?.clearActionJournal();
  }
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(
    storage: const SecureOrderStorage(),
    backendApi: const SupabaseOrderBackendApi(),
  ),
);
