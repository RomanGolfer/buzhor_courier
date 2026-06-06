import 'dart:async';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _logRealtimeDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class RealtimeOrderListener extends ConsumerStatefulWidget {
  final Widget child;

  const RealtimeOrderListener({super.key, required this.child});

  @override
  ConsumerState<RealtimeOrderListener> createState() =>
      _RealtimeOrderListenerState();
}

class _RealtimeOrderListenerState extends ConsumerState<RealtimeOrderListener> {
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  String? _sessionUserId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initializeRealtime);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _initializeRealtime() {
    final client = SupabaseBackend.client;
    if (client == null) return;

    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      final userId = data.session?.user.id;
      if (userId == _sessionUserId) return;
      _sessionUserId = userId;
      _resetSubscription();
      if (userId != null) {
        unawaited(_subscribe());
        if (mounted) {
          ref.read(ordersProvider.notifier).refreshOrders();
        }
      }
    });

    final userId = client.auth.currentSession?.user.id;
    if (userId == null) return;
    _sessionUserId = userId;
    unawaited(_subscribe());
    ref.read(ordersProvider.notifier).refreshOrders();
  }

  Future<void> _subscribe() async {
    final client = SupabaseBackend.client;
    if (client == null || client.auth.currentSession == null) return;
    final userId = client.auth.currentSession!.user.id;
    final courierId = await _currentCourierId(client, userId);
    if (!mounted || userId != _sessionUserId) return;

    if (courierId == null) {
      _logRealtimeDebug('Realtime subscription skipped: courier id not found');
      return;
    }

    _channel?.unsubscribe();
    _channel = client
        .channel('orders-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_courier_id',
            value: courierId,
          ),
          callback: _handleChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_courier_id',
            value: courierId,
          ),
          callback: _handleChange,
        )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
          if (error != null) {
            _logRealtimeDebug('Realtime subscribe error: $error');
          }
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && _channel != null) _subscribe();
            });
          }
        });
  }

  Future<String?> _currentCourierId(
    SupabaseClient client,
    String userId,
  ) async {
    try {
      final row = await client
          .from('couriers')
          .select('id')
          .eq('profile_id', userId)
          .eq('is_active', true)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (error) {
      _logRealtimeDebug('Failed to resolve realtime courier id: $error');
      return null;
    }
  }

  void _resetSubscription() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void _handleChange(PostgresChangePayload payload) {
    if (!mounted) return;
    if (payload.newRecord.isEmpty) {
      ref.read(ordersProvider.notifier).refreshOrders();
      return;
    }

    try {
      final order = OrderItem.fromBackendJson(payload.newRecord);
      ref.read(ordersProvider.notifier).updateOrder(order);
    } catch (e) {
      _logRealtimeDebug('Realtime order parse error: $e');
      ref.read(ordersProvider.notifier).refreshOrders();
    }
  }
}
