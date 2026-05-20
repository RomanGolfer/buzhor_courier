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
    final service = ref.read(pushNotificationServiceProvider);
    await service.initialize();
    if (!mounted) return;

    _subscription = service.events.listen(_handleEvent);
  }

  Future<void> _handleEvent(PushNotificationEvent event) async {
    switch (event) {
      case NewOrderPushEvent(:final order):
        await ref.read(ordersProvider.notifier).upsertIncomingOrder(order);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Новый заказ ${order.displayId}')),
          );
    }
  }
}
