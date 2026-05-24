import 'package:buzhor_courier/features/orders/data/order_repository.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:buzhor_courier/features/orders/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const _activeOrder = OrderItem(
  id: '#3',
  clientName: 'Активный клиент',
  address: 'ул. Тестовая, 3',
  district: 'Анапа',
  price: 900,
  payment: PaymentType.cash,
  bottles: 3,
  lat: 44.8951,
  lng: 37.3168,
);

const _activeScannedOrder = OrderItem(
  id: '#5',
  clientName: 'Клиент с маркировкой',
  address: 'ул. Тестовая, 5',
  district: 'Анапа',
  price: 900,
  payment: PaymentType.cash,
  bottles: 3,
  scannedItems: {'water': 2},
  lat: 44.8951,
  lng: 37.3168,
);

const _qrOrder = OrderItem(
  id: '#4',
  clientName: 'Клиент с QR',
  address: 'ул. Тестовая, 4',
  district: 'Анапа',
  price: 900,
  payment: PaymentType.qr,
  bottles: 3,
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
    expect(find.text('Картой курьеру'), findsWidgets);
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

  testWidgets('payment selector offers only courier payment methods', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _activeOrder)),
      ),
    );

    await tester.tap(find.text('Наличные').first);
    await tester.pumpAndSettle();

    expect(find.text('Выберите способ оплаты'), findsOneWidget);
    expect(find.text('Картой курьеру'), findsOneWidget);
    expect(find.text('По договору'), findsOneWidget);
    expect(find.text('Наличные'), findsWidgets);
    expect(find.text('Онлайн оплата'), findsNothing);
    expect(find.text('Оплачено'), findsNothing);
  });

  testWidgets('keeps selected payment when payment sync fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(
            _FailingOrderRepository([_activeOrder]),
          ),
        ],
        child: const MaterialApp(home: OrderDetailScreen(order: _activeOrder)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('paymentTypeSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paymentTypeCardOption')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    final paymentText = tester.widget<Text>(
      find.byKey(const Key('paymentTypeValue')),
    );
    expect(paymentText.data, 'Картой');
    expect(
      find.byKey(const Key('orderDetailSyncErrorSnackBar')),
      findsOneWidget,
    );
  });

  testWidgets('shows payment QR for QR orders', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _qrOrder)),
      ),
    );

    expect(find.text('QR для оплаты'), findsOneWidget);
    expect(find.text('900 ₽'), findsOneWidget);
    expect(find.text('Заказ #4'), findsOneWidget);
  });

  testWidgets('opens screenshot-friendly payment QR screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _qrOrder)),
      ),
    );

    await tester.tap(find.text('Открыть крупно'));
    await tester.pumpAndSettle();

    expect(find.text('QR для оплаты'), findsWidgets);
    expect(find.text('Заказ #4'), findsOneWidget);
    expect(find.text('К оплате'), findsOneWidget);
    expect(find.text('900 ₽'), findsOneWidget);
    expect(find.text('Клиент с QR'), findsNothing);
  });

  testWidgets('opens payment QR screen when tapping compact QR', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _qrOrder)),
      ),
    );

    await tester.tap(find.byKey(const Key('compactPaymentQrTapTarget')).first);
    await tester.pumpAndSettle();

    expect(find.text('К оплате'), findsOneWidget);
    expect(find.text('900 ₽'), findsOneWidget);
  });

  testWidgets('shows payment QR generation action in delivery sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _activeOrder)),
      ),
    );

    await tester.tap(find.text('Доставлен'));
    await tester.pumpAndSettle();

    expect(find.text('Маркировка товаров'), findsOneWidget);
    expect(find.text('Сгенерировать QR для оплаты'), findsOneWidget);

    await tester.tap(find.text('Сгенерировать QR для оплаты'));
    await tester.pumpAndSettle();

    expect(find.text('QR для оплаты'), findsOneWidget);
    expect(find.text('Заказ #3'), findsOneWidget);
    expect(find.text('900 ₽'), findsOneWidget);

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Онлайн'), findsWidgets);
    expect(find.text('Открыть крупно'), findsOneWidget);
  });

  testWidgets(
    'keeps scanned marking state and allows reset in delivery sheet',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OrderDetailScreen(order: _activeScannedOrder),
          ),
        ),
      );

      expect(find.text('2 / 3 отсканировано'), findsOneWidget);

      await tester.tap(find.text('Доставлен'));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3 отсканировано'), findsWidgets);
      expect(find.text('Сбросить'), findsOneWidget);

      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();

      expect(find.text('0 / 3 отсканировано'), findsOneWidget);
      expect(find.text('Сбросить'), findsNothing);
    },
  );

  testWidgets('copies order number from payment QR screen', (tester) async {
    final clipboardWrites = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = call.arguments as Map<dynamic, dynamic>;
            clipboardWrites.add(data['text'] as String);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _qrOrder)),
      ),
    );

    await tester.tap(find.text('Открыть крупно'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Заказ #4'));
    await tester.pump();

    expect(clipboardWrites, ['#4']);
    expect(find.text('Номер заказа скопирован'), findsOneWidget);
  });

  testWidgets('shows company logo on payment QR screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _qrOrder)),
      ),
    );

    await tester.tap(find.text('Открыть крупно'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paymentQrLogo')), findsOneWidget);
  });

  testWidgets('shows payment check placeholder on QR screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _qrOrder)),
      ),
    );

    await tester.tap(find.text('Открыть крупно'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Проверить оплату'));
    await tester.tap(find.text('Проверить оплату'));
    await tester.pump();

    expect(find.text('Проверяем...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Проверка оплаты пока не подключена'), findsWidgets);
  });

  testWidgets('auto polls payment status on QR screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(order: _qrOrder)),
      ),
    );

    await tester.tap(find.text('Открыть крупно'));
    await tester.pumpAndSettle();

    expect(find.text('Проверка оплаты пока не подключена'), findsNothing);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Проверка оплаты пока не подключена'), findsOneWidget);
  });
}

class _FailingOrderRepository extends OrderRepository {
  _FailingOrderRepository(List<OrderItem> initialOrders)
    : super(initialOrders: initialOrders);

  @override
  Future<List<OrderItem>> upsertOrder(OrderItem incomingOrder) async {
    throw StateError('payment sync failed');
  }
}
