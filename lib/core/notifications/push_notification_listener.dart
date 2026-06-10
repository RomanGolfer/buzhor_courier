import 'dart:async';

import 'package:buzhor_courier/core/notifications/push_notification_service.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PushNotificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const PushNotificationListener({super.key, required this.child});

  @override
  ConsumerState<PushNotificationListener> createState() =>
      _PushNotificationListenerState();
}

class _PushNotificationListenerState
    extends ConsumerState<PushNotificationListener> {
  StreamSubscription<PushNotificationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(_subscribe);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _subscribe() async {
    if (!mounted) return;
    final service = ref.read(pushNotificationServiceProvider);
    // Subscribe before initialize() so events emitted during initialization
    // (e.g. getInitialMessage on cold start from a notification tap) are not
    // dropped by the broadcast stream before the listener is registered.
    _subscription?.cancel();
    _subscription = service.events.listen(_handleEvent);
    await service.initialize();
  }

  Future<void> _handleEvent(PushNotificationEvent event) async {
    if (!mounted) return;
    switch (event) {
      case NewOrderPushEvent(:final order):
        await ref.read(ordersProvider.notifier).upsertIncomingOrder(order);
        unawaited(ref.read(ordersProvider.notifier).refreshOrders());
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Новый заказ ${order.displayId}')),
          );
      case NewOrderRefreshRequestedEvent():
        await ref.read(ordersProvider.notifier).refreshOrders();
    }
  }
}
