import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/providers/location_provider.dart';
import 'package:buzhor_courier/features/orders/screens/home_screen.dart';
import 'package:buzhor_courier/features/orders/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _longOrder = OrderItem(
  id: '#1234567890',
  orderNumber: '#1234567890',
  clientName: 'Очень длинное имя клиента для проверки карточки',
  address:
      'Очень длинный адрес доставки, который должен занимать две строки без роста карточки',
  district: 'Очень длинный район',
  price: 12840,
  payment: PaymentType.contract,
  bottles: 24,
  lat: 44.8951,
  lng: 37.3168,
  comment: 'Длинный комментарий диспетчера, который не должен ломать карточку',
);

void main() {
  testWidgets('empty active list can be refreshed without restarting the app', (
    tester,
  ) async {
    final repository = _CountingOrderRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(repository),
          locationProvider.overrideWith((ref) => _NoopLocationNotifier()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Обновить'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.reloadCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order card keeps long text inside a narrow card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: OrderCard(order: _longOrder, number: 99),
          ),
        ),
      ),
    );

    expect(find.byType(OrderCard), findsOneWidget);
    final addressText = tester.widget<Text>(find.text(_longOrder.address));
    expect(addressText.maxLines, 2);
    expect(addressText.overflow, TextOverflow.ellipsis);
    expect(addressText.style?.fontSize, lessThan(15));
    expect(tester.takeException(), isNull);
  });
}

class _CountingOrderRepository extends OrderRepository {
  _CountingOrderRepository() : super(initialOrders: const []);

  int reloadCount = 0;

  @override
  Future<List<OrderItem>> reloadOrders() async {
    reloadCount += 1;
    return const [];
  }
}

class _NoopLocationNotifier extends LocationNotifier {
  @override
  Future<void> refreshLocation() async {}
}
