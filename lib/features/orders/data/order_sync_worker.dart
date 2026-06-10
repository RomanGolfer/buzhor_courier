import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
  bool get canSync => _client != null && SupabaseBackend.currentSession != null;

  @override
  Future<OrderSyncDispatchResult> dispatch(OrderSyncOperation operation) async {
    final client = _client;
    final session = await SupabaseBackend.refreshSessionIfNeeded();
    final userId = session?.user.id;
    if (client == null || session == null || userId == null) {
      throw StateError('Supabase session is not available');
    }
    final deviceId = await _loadOrCreateSyncDeviceId();

    final payload = {
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
      'device_id': deviceId,
      'session_id': _sessionIdFromAccessToken(session.accessToken),
      'client_platform': defaultTargetPlatform.name,
    };

    final row = await _insertOrLoadExistingOperation(
      client,
      payload,
      operation,
    );

    return OrderSyncDispatchResult(
      status: _syncStatusFromBackend(row['status'] as String?),
      lastError: row['last_error'] as String?,
      ackedAt: _optionalDateTime(row['acked_at'] as String?),
    );
  }
}

Future<Map<String, dynamic>> _insertOrLoadExistingOperation(
  SupabaseClient client,
  Map<String, dynamic> payload,
  OrderSyncOperation operation,
) async {
  try {
    return await client
        .from('sync_operations')
        .insert(payload)
        .select('status,last_error,acked_at')
        .single();
  } on PostgrestException catch (error) {
    if (!_isDuplicateOperationId(error)) rethrow;
    return client
        .from('sync_operations')
        .select('status,last_error,acked_at')
        .eq('operation_id', operation.operationId)
        .single();
  }
}

bool _isDuplicateOperationId(PostgrestException error) {
  return error.code == '23505' ||
      error.message.contains('sync_operations_operation_id_key');
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
      }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
    } catch (error) {
      debugPrint('[OrderSyncWorker] Sync failed: $error');
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

const _syncDeviceIdStorageKey = 'orders_sync_device_id_v1';
const _secureStorage = FlutterSecureStorage();
final _uuid = Uuid();

Future<String> _loadOrCreateSyncDeviceId() async {
  final saved = await _secureStorage.read(key: _syncDeviceIdStorageKey);
  if (saved != null && saved.isNotEmpty) return saved;

  final deviceId = _uuid.v4();
  await _secureStorage.write(key: _syncDeviceIdStorageKey, value: deviceId);
  return deviceId;
}

String? _sessionIdFromAccessToken(String? accessToken) {
  if (accessToken == null || accessToken.isEmpty) return null;
  final parts = accessToken.split('.');
  if (parts.length < 2) return null;

  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;
    final sessionId = decoded['session_id'];
    return sessionId is String && sessionId.isNotEmpty ? sessionId : null;
  } catch (_) {
    return null;
  }
}
