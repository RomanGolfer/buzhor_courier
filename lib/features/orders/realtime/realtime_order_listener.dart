import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeOrderListener extends ConsumerStatefulWidget {
  final Widget child;

  const RealtimeOrderListener({super.key, required this.child});

  @override
  ConsumerState<RealtimeOrderListener> createState() =>
      _RealtimeOrderListenerState();
}

class _RealtimeOrderListenerState extends ConsumerState<RealtimeOrderListener> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    Future.microtask(_subscribe);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _subscribe() {
    final client = SupabaseBackend.client;
    if (client == null) return;

    _channel = client
        .channel('orders-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: _handleChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: _handleChange,
        )
        .subscribe();
  }

  void _handleChange(PostgresChangePayload payload) {
    if (!mounted) return;
    final record = payload.newRecord;
    if (record.isEmpty) return;

    try {
      final order = OrderItem.fromBackendJson(record);
      ref.read(ordersProvider.notifier).updateOrder(order);
    } catch (_) {}
  }
}
