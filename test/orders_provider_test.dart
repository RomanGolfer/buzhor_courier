import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/orders_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const _activeOrder = OrderItem(
  id: '#1',
  clientName: 'Тестовый клиент',
  address: 'ул. Тестовая, 1',
  district: 'Анапа',
  price: 560,
  payment: PaymentType.cash,
  bottles: 2,
  lat: 44.8951,
  lng: 37.3168,
);

void main() {
  test(
    'completeOrder moves active order to completed with delivery details',
    () async {
      final notifier = OrdersNotifier(
        OrderRepository(initialOrders: [_activeOrder]),
      );
      await Future<void>.delayed(Duration.zero);

      await notifier.completeOrder(
        _activeOrder.id,
        bottles: 3,
        returnedBottles: 1,
        paymentType: PaymentType.card,
        extras: {'Помпа': 1},
        comment: 'Оставлено у двери',
      );

      expect(notifier.state.activeOrders, isEmpty);
      expect(notifier.state.timeSlots, isEmpty);
      expect(notifier.state.completedOrders, hasLength(1));

      final completed = notifier.state.completedOrders.single;
      expect(completed.effectiveDeliveryState, OrderDeliveryState.delivered);
      expect(completed.deliveredBottles, 3);
      expect(completed.returnedBottles, 1);
      expect(completed.confirmedPayment, PaymentType.card);
      expect(completed.extras, {'Помпа': 1});
      expect(completed.deliveryComment, 'Оставлено у двери');
    },
  );

  test(
    'failOrder moves active order to completed with failure reason',
    () async {
      final notifier = OrdersNotifier(
        OrderRepository(initialOrders: [_activeOrder]),
      );
      await Future<void>.delayed(Duration.zero);

      await notifier.failOrder(_activeOrder.id, reason: 'Клиент не отвечает');

      expect(notifier.state.activeOrders, isEmpty);
      expect(notifier.state.completedOrders, hasLength(1));

      final failed = notifier.state.completedOrders.single;
      expect(failed.effectiveDeliveryState, OrderDeliveryState.failed);
      expect(failed.isFailed, isTrue);
      expect(failed.failureReason, 'Клиент не отвечает');
    },
  );

  test('failOrder ignores blank reasons', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.failOrder(_activeOrder.id, reason: '   ');

    expect(notifier.state.activeOrders, [_activeOrder]);
    expect(notifier.state.completedOrders, isEmpty);
  });

  test('refreshOrders keeps repository mutations', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.completeOrder(
      _activeOrder.id,
      bottles: 2,
      returnedBottles: 0,
      paymentType: PaymentType.cash,
      extras: const {},
    );
    await notifier.refreshOrders();

    expect(notifier.state.activeOrders, isEmpty);
    expect(notifier.state.completedOrders, hasLength(1));
    expect(
      notifier.state.completedOrders.single.effectiveDeliveryState,
      OrderDeliveryState.delivered,
    );
  });
}
