import 'dart:async';
import 'dart:math';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class OrderSyncDispatcher {
  bool get canSync;
  Future<void> dispatch(OrderSyncOperation operation);
}

class SupabaseOrderSyncDispatcher implements OrderSyncDispatcher {
  const SupabaseOrderSyncDispatcher();

  SupabaseClient? get _client => SupabaseBackend.client;

  @override
  bool get canSync => _client?.auth.currentSession != null;

  @override
  Future<void> dispatch(OrderSyncOperation operation) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Supabase session is not available');
    }

    await client.from('sync_operations').upsert({
      'operation_id': operation.operationId,
      'operation_type': operation.backendType,
      'status': 'pending',
      'order_id': operation.orderId,
      'order_version': operation.orderVersion,
      'actor_profile_id': userId,
      'payload': operation.payload,
      'attempt_count': operation.attemptCount,
      'next_attempt_at': operation.nextAttemptAt?.toIso8601String(),
      'last_error': operation.lastError,
    }, onConflict: 'operation_id');
  }
}

class OrderSyncWorker {
  static final instance = OrderSyncWorker._(
    storage: const SharedPreferencesOrderStorage(),
    dispatcher: const SupabaseOrderSyncDispatcher(),
  );

  OrderSyncWorker({
    required OrderStorage storage,
    required OrderSyncDispatcher dispatcher,
    Duration pollInterval = _defaultPollInterval,
  }) : _storage = storage,
       _dispatcher = dispatcher,
       _pollInterval = pollInterval;

  OrderSyncWorker._({
    required OrderStorage storage,
    required OrderSyncDispatcher dispatcher,
  }) : this(
         storage: storage,
         dispatcher: dispatcher,
         pollInterval: _defaultPollInterval,
       );

  static const _maxAttempts = 5;
  static const _defaultPollInterval = Duration(seconds: 60);
  static const _maxBackoffSeconds = 900;

  final OrderStorage _storage;
  final OrderSyncDispatcher _dispatcher;
  final Duration _pollInterval;
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
    if (!_dispatcher.canSync) return;

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
          await _dispatcher.dispatch(op);
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
}
