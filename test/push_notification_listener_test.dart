import 'dart:async';

import 'package:buzhor_courier/core/notifications/push_notification_listener.dart';
import 'package:buzhor_courier/core/notifications/push_notification_service.dart';
import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _incomingOrder = OrderItem(
  id: '#99',
  clientName: 'Пуш клиент',
  address: 'ул. Пуш, 99',
  district: 'Анапа',
  price: 560,
  payment: PaymentType.cash,
  bottles: 2,
  lat: 44.8951,
  lng: 37.3168,
);

void main() {
  testWidgets('adds pushed order and shows feedback', (tester) async {
    final service = _FakePushNotificationService();
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationServiceProvider.overrideWithValue(service),
          orderRepositoryProvider.overrideWithValue(
            OrderRepository(initialOrders: const []),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const PushNotificationListener(
                child: Scaffold(body: SizedBox()),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    service.add(const NewOrderPushEvent(order: _incomingOrder));
    await tester.pumpAndSettle();

    final ordersState = container.read(ordersProvider);
    expect(ordersState.activeOrders.single.id, _incomingOrder.id);
    expect(find.text('Новый заказ #99'), findsOneWidget);
  });

  testWidgets('refreshes orders when pushed order payload cannot be loaded', (
    tester,
  ) async {
    final service = _FakePushNotificationService();
    final repository = _ReloadingOrderRepository();
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationServiceProvider.overrideWithValue(service),
          orderRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const PushNotificationListener(
                child: Scaffold(body: SizedBox()),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    service.add(const NewOrderRefreshRequestedEvent(orderId: '#99'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(repository.reloadCount, 1);
    expect(container.read(ordersProvider).activeOrders.single.id, '#99');
  });
}

class _FakePushNotificationService implements PushNotificationService {
  final _controller = StreamController<PushNotificationEvent>.broadcast();

  @override
  Stream<PushNotificationEvent> get events => _controller.stream;

  @override
  Future<void> initialize() async {}

  void add(PushNotificationEvent event) {
    _controller.add(event);
  }
}

class _ReloadingOrderRepository extends OrderRepository {
  _ReloadingOrderRepository() : super(initialOrders: const []);

  int reloadCount = 0;

  @override
  Future<List<OrderItem>> reloadOrders() async {
    reloadCount += 1;
    return const [_incomingOrder];
  }
}
