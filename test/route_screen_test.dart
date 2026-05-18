import 'package:buzhor_courier/features/route/screens/route_screen.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _orders = [
  OrderItem(
    id: '#1',
    clientName: 'Клиент 1',
    address: 'ул. Тестовая, 1',
    district: 'Анапа',
    price: 560,
    payment: PaymentType.cash,
    bottles: 2,
    lat: 44.8951,
    lng: 37.3168,
  ),
  OrderItem(
    id: '#2',
    clientName: 'Клиент 2',
    address: 'ул. Тестовая, 2',
    district: 'Анапа',
    price: 840,
    payment: PaymentType.card,
    bottles: 3,
    lat: 44.9021,
    lng: 37.3378,
  ),
];

void main() {
  testWidgets('shows empty state when route has no active orders', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RouteScreen(orders: [])));

    expect(find.text('Нет активных заказов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows low data route mode when enabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RouteScreen(orders: _orders, initialLowDataMode: true),
      ),
    );

    expect(find.text('2G включён'), findsOneWidget);
  });
}
