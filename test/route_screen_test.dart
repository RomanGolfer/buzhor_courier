import 'package:buzhor_courier/features/route/screens/route_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty state when route has no active orders', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RouteScreen(orders: [])));

    expect(find.text('Нет активных заказов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
