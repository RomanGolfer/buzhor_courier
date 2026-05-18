import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/data/order_storage.dart';
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

const _incomingOrder = OrderItem(
  id: '#2',
  clientName: 'Новый клиент',
  address: 'ул. Новая, 2',
  district: 'Анапа',
  price: 840,
  payment: PaymentType.cash,
  bottles: 3,
  lat: 44.9021,
  lng: 37.3378,
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
        scannedItems: {'water': 3},
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
      expect(completed.scannedItems, {'water': 3});
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
      scannedItems: const {'water': 2},
    );
    await notifier.refreshOrders();

    expect(notifier.state.activeOrders, isEmpty);
    expect(notifier.state.completedOrders, hasLength(1));
    expect(
      notifier.state.completedOrders.single.effectiveDeliveryState,
      OrderDeliveryState.delivered,
    );
  });

  test('toggleLowDataMode switches global low data mode', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isLowDataMode, isFalse);

    notifier.toggleLowDataMode();
    expect(notifier.state.isLowDataMode, isTrue);

    notifier.toggleLowDataMode();
    expect(notifier.state.isLowDataMode, isFalse);
  });

  test('repository restores saved orders from local storage', () async {
    final storage = _FakeOrderStorage();
    final repository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
    );

    await repository.completeOrder(
      _activeOrder.id,
      bottles: 2,
      returnedBottles: 0,
      paymentType: PaymentType.cash,
      extras: const {},
      scannedItems: const {'water': 2},
    );

    final restoredRepository = OrderRepository(
      initialOrders: [_activeOrder],
      storage: storage,
    );
    final restored = await restoredRepository.fetchOrders();

    expect(
      restored.single.effectiveDeliveryState,
      OrderDeliveryState.delivered,
    );
    expect(restored.single.scannedItems, {'water': 2});
  });

  test('upsertIncomingOrder adds new pushed order', () async {
    final notifier = OrdersNotifier(
      OrderRepository(initialOrders: [_activeOrder]),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.upsertIncomingOrder(_incomingOrder);

    expect(notifier.state.activeOrders.map((order) => order.id), [
      _activeOrder.id,
      _incomingOrder.id,
    ]);
  });
}

class _FakeOrderStorage implements OrderStorage {
  List<OrderItem>? savedOrders;

  @override
  Future<List<OrderItem>?> loadOrders() async {
    return savedOrders == null ? null : List<OrderItem>.of(savedOrders!);
  }

  @override
  Future<void> saveOrders(List<OrderItem> orders) async {
    savedOrders = List<OrderItem>.of(orders);
  }
}
