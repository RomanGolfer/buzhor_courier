import 'dart:async';
import 'dart:math';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderSyncWorker {
  static final instance = OrderSyncWorker._(
    storage: const SharedPreferencesOrderStorage(),
  );

  OrderSyncWorker._({required OrderStorage storage}) : _storage = storage;

  static const _maxAttempts = 5;
  static const _pollInterval = Duration(seconds: 60);
  static const _maxBackoffSeconds = 900;

  final OrderStorage _storage;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => sync());

    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) sync();
    });

    sync();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    final client = SupabaseBackend.client;
    if (client == null || client.auth.currentSession == null) return;

    _isSyncing = true;
    try {
      final operations = await _storage.loadSyncOperations();
      final now = DateTime.now();
      final pending = operations.where((op) {
        return op.status == OrderSyncOperationStatus.pending &&
            (op.nextAttemptAt == null || op.nextAttemptAt!.isBefore(now));
      }).toList();

      if (pending.isEmpty) return;

      final updated = List<OrderSyncOperation>.from(operations);

      for (final op in pending) {
        final idx = updated.indexWhere((o) => o.operationId == op.operationId);
        if (idx == -1) continue;

        try {
          await _dispatch(client, op);
          updated[idx] = op.copyWith(
            status: OrderSyncOperationStatus.acked,
            ackedAt: DateTime.now(),
          );
        } catch (e) {
          final newCount = op.attemptCount + 1;
          if (newCount >= _maxAttempts) {
            updated[idx] = op.copyWith(
              attemptCount: newCount,
              status: OrderSyncOperationStatus.needsReview,
              lastError: e.toString(),
            );
          } else {
            final backoffSec = min(_maxBackoffSeconds, 30 * (1 << newCount));
            updated[idx] = op.copyWith(
              attemptCount: newCount,
              lastError: e.toString(),
              nextAttemptAt: DateTime.now().add(Duration(seconds: backoffSec)),
            );
          }
        }
      }

      await _storage.saveSyncOperations(updated);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _dispatch(SupabaseClient client, OrderSyncOperation op) async {
    final p = op.payload;
    switch (op.type) {
      case OrderSyncOperationType.complete:
        await client.from('orders').update({
          'state': 'delivered',
          'delivered_bottles': p['bottles'] as int,
          'returned_bottles': p['returnedBottles'] as int,
          'confirmed_payment': p['paymentType'] as String,
          'extras': p['extras'],
          'scanned_items': p['scannedItems'],
          'delivery_comment': p['comment'],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', op.orderId);

      case OrderSyncOperationType.fail:
        await client.from('orders').update({
          'state': 'failed',
          'failure_reason': p['reason'] as String,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', op.orderId);
    }
  }
}
