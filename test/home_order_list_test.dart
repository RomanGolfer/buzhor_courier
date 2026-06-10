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
  clientName: 'Very long customer name used to check card constraints',
  address:
      'Very long delivery address that should stay inside two lines without growing the card',
  district: 'Very long district',
  price: 12840,
  payment: PaymentType.contract,
  bottles: 24,
  lat: 44.8951,
  lng: 37.3168,
  comment: 'Long dispatcher comment that should not break card layout',
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

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.reloadCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orders refresh when app returns to foreground', (tester) async {
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

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

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

  testWidgets('new order card shows new badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrderCard(order: _longOrder, number: 1, isNew: true),
        ),
      ),
    );

    expect(find.byKey(const Key('orderNewBadge')), findsOneWidget);
  });

  testWidgets('order card shows delivery date and client rating', (
    tester,
  ) async {
    final order = _longOrder.copyWith(
      clientRating: const ClientRating(rating: 4),
      deliveryDate: DateTime(2026, 5, 27),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OrderCard(order: order, number: 1)),
      ),
    );

    expect(find.byKey(const Key('orderDeliveryDateBadge')), findsOneWidget);
    expect(find.byKey(const Key('orderClientRatingBadge')), findsOneWidget);
    expect(find.text('27.05'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
  });

  testWidgets('daily report shows courier summary sections', (tester) async {
    final repository = OrderRepository(
      initialOrders: const [
        OrderItem(
          id: '#done',
          clientName: 'Client',
          address: 'Address',
          district: 'District',
          price: 600,
          payment: PaymentType.cash,
          bottles: 2,
          lat: 44,
          lng: 37,
          isDone: true,
          deliveredBottles: 2,
          returnedBottles: 1,
          confirmedPayment: PaymentType.cash,
        ),
        OrderItem(
          id: '#active',
          clientName: 'Client 2',
          address: 'Address 2',
          district: 'District',
          price: 300,
          payment: PaymentType.qr,
          bottles: 1,
          lat: 44,
          lng: 37,
        ),
      ],
    );

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

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dailyReportOrdersSection')), findsOneWidget);
    expect(find.byKey(const Key('dailyReportPaymentsSection')), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dailyReportReturnsSection')), findsOneWidget);
    expect(find.byKey(const Key('dailyReportWaterSection')), findsOneWidget);
    expect(
      find.byKey(const Key('dailyReportOtherGoodsSection')),
      findsOneWidget,
    );
  });

  testWidgets('completed tab shows only orders closed today', (tester) async {
    final nowMoscow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final yesterday = nowMoscow.subtract(const Duration(days: 1));
    final repository = OrderRepository(
      initialOrders: [
        OrderItem(
          id: '#today',
          clientName: 'Client',
          address: 'Address',
          district: 'District',
          price: 600,
          payment: PaymentType.cash,
          bottles: 2,
          lat: 44,
          lng: 37,
          isDone: true,
          deliveryState: OrderDeliveryState.delivered,
          deliveryDate: DateTime(
            nowMoscow.year,
            nowMoscow.month,
            nowMoscow.day,
          ),
          updatedAt: DateTime.now().toUtc(),
        ),
        OrderItem(
          id: '#old',
          clientName: 'Old client',
          address: 'Old address',
          district: 'District',
          price: 300,
          payment: PaymentType.cash,
          bottles: 1,
          lat: 44,
          lng: 37,
          isDone: true,
          deliveryState: OrderDeliveryState.delivered,
          deliveryDate: DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
          ),
          updatedAt: DateTime.now().toUtc(),
        ),
      ],
    );

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

    await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(OrderCard), findsOneWidget);
    expect(find.text('#today'), findsOneWidget);
    expect(find.text('#old'), findsNothing);
  });

  testWidgets('completed tab is empty when only older orders are closed', (
    tester,
  ) async {
    final repository = OrderRepository(
      initialOrders: [
        OrderItem(
          id: '#old',
          clientName: 'Old client',
          address: 'Old address',
          district: 'District',
          price: 300,
          payment: PaymentType.cash,
          bottles: 1,
          lat: 44,
          lng: 37,
          isDone: true,
          deliveryState: OrderDeliveryState.delivered,
          updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        ),
      ],
    );

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

    await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(OrderCard), findsNothing);
    expect(find.text('#old'), findsNothing);
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
