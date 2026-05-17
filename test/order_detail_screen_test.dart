import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _deliveredOrder = OrderItem(
  id: '#1',
  clientName: 'Тестовый клиент',
  address: 'ул. Тестовая, 1',
  district: 'Анапа',
  price: 560,
  payment: PaymentType.cash,
  bottles: 2,
  deliveryState: OrderDeliveryState.delivered,
  deliveredBottles: 3,
  returnedBottles: 1,
  confirmedPayment: PaymentType.card,
  extras: {'Помпа': 1},
  scannedItems: {'water': 3},
  deliveryComment: 'Оставлено у двери',
  lat: 44.8951,
  lng: 37.3168,
);

const _failedOrder = OrderItem(
  id: '#2',
  clientName: 'Другой клиент',
  address: 'ул. Тестовая, 2',
  district: 'Анапа',
  price: 560,
  payment: PaymentType.cash,
  bottles: 2,
  deliveryState: OrderDeliveryState.failed,
  failureReason: 'Клиент не отвечает',
  lat: 44.8951,
  lng: 37.3168,
);

void main() {
  testWidgets('shows delivered order result in read-only mode', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _deliveredOrder)),
      ),
    );

    expect(find.text('Результат заказа'), findsOneWidget);
    expect(find.text('Доставлено'), findsOneWidget);
    expect(find.text('3 бут.'), findsOneWidget);
    expect(find.text('Возврат'), findsOneWidget);
    expect(find.text('1 бут.'), findsOneWidget);
    expect(find.text('Карта'), findsWidgets);
    expect(find.text('Помпа ×1'), findsWidgets);
    expect(find.text('Маркировка'), findsOneWidget);
    expect(find.text('3 отсканировано'), findsOneWidget);
    expect(find.text('Оставлено у двери'), findsOneWidget);
    expect(find.text('+ Добавить'), findsNothing);
  });

  testWidgets('shows failed order reason', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _failedOrder)),
      ),
    );

    expect(find.text('Результат заказа'), findsOneWidget);
    expect(find.text('Не доставлен'), findsOneWidget);
    expect(find.text('Причина'), findsOneWidget);
    expect(find.text('Клиент не отвечает'), findsOneWidget);
    expect(find.text('+ Добавить'), findsNothing);
  });
}
