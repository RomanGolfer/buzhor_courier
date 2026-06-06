import 'dart:async';
import 'dart:math';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class OrderSyncDispatcher {
  bool get canSync;
  Future<OrderSyncDispatchResult> dispatch(OrderSyncOperation operation);
}

class OrderSyncDispatchResult {
  final OrderSyncOperationStatus status;
  final String? lastError;
  final DateTime? ackedAt;

  const OrderSyncDispatchResult({
    required this.status,
    this.lastError,
    this.ackedAt,
  });

  const OrderSyncDispatchResult.acked()
    : status = OrderSyncOperationStatus.acked,
      lastError = null,
      ackedAt = null;
}

class SupabaseOrderSyncDispatcher implements OrderSyncDispatcher {
  const SupabaseOrderSyncDispatcher();

  SupabaseClient? get _client => SupabaseBackend.client;

  @override
  bool get canSync => _client?.auth.currentSession != null;

  @override
  Future<OrderSyncDispatchResult> dispatch(OrderSyncOperation operation) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Supabase session is not available');
    }

    final row = await client
        .from('sync_operations')
        .upsert({
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
        }, onConflict: 'operation_id')
        .select('status,last_error,acked_at')
        .single();

    return OrderSyncDispatchResult(
      status: _syncStatusFromBackend(row['status'] as String?),
      lastError: row['last_error'] as String?,
      ackedAt: _optionalDateTime(row['acked_at'] as String?),
    );
  }
}

class OrderSyncWorker {
  static final instance = OrderSyncWorker._(
    storage: const SecureOrderStorage(),
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
  StreamSubscription<AuthState>? _authSub;
  bool _isSyncing = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => sync());

    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) sync();
    });

    _authSub?.cancel();
    _authSub = SupabaseBackend.client?.auth.onAuthStateChange.listen((event) {
      if (event.session != null) sync();
    });

    sync();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _authSub?.cancel();
    _authSub = null;
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
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (pending.isEmpty) return;

      final updated = List<OrderSyncOperation>.from(operations);

      for (final op in pending) {
        final idx = updated.indexWhere((o) => o.operationId == op.operationId);
        if (idx == -1) continue;

        try {
          final result = await _dispatcher.dispatch(op);
          updated[idx] = op.copyWith(
            status: result.status,
            nextAttemptAt: null,
            lastError: result.lastError,
            ackedAt: result.ackedAt ?? DateTime.now(),
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
        await _storage.saveSyncOperations(updated);
      }
    } finally {
      _isSyncing = false;
    }
  }
}

OrderSyncOperationStatus _syncStatusFromBackend(String? value) {
  return switch (value) {
    'acked' => OrderSyncOperationStatus.acked,
    'rejected' => OrderSyncOperationStatus.rejected,
    'needs_review' => OrderSyncOperationStatus.needsReview,
    'in_flight' => OrderSyncOperationStatus.inFlight,
    _ => OrderSyncOperationStatus.pending,
  };
}

DateTime? _optionalDateTime(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
