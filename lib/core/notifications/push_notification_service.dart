import 'dart:async';

import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class PushNotificationEvent {
  const PushNotificationEvent();
}

class NewOrderPushEvent extends PushNotificationEvent {
  final OrderItem order;

  const NewOrderPushEvent({required this.order});
}

abstract class PushNotificationService {
  Stream<PushNotificationEvent> get events;
  Future<void> initialize();
}

class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Stream<PushNotificationEvent> get events => const Stream.empty();

  @override
  Future<void> initialize() async {}
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => const NoopPushNotificationService(),
);
