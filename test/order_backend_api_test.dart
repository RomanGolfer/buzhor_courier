import 'package:buzhor_courier/features/orders/data/order_backend_api.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fetchAssignedOrders returns null when Supabase is not initialized', () async {
    const api = SupabaseOrderBackendApi();
    expect(await api.fetchAssignedOrders(), isNull);
  });

  test('parseOrderRows silently skips rows that fail to parse', () {
    final rows = [
      {'id': 'abc', 'client_name': 'Valid Client'},
      {'not_an_id': 'missing required id field'},
      {'id': 'def', 'client_name': 'Another Valid'},
    ];

    final orders = SupabaseOrderBackendApi.parseOrderRows(rows);

    expect(orders.length, 2);
    expect(orders[0].id, 'abc');
    expect(orders[1].id, 'def');
  });

  test('parseOrderRows returns empty list for empty input', () {
    expect(SupabaseOrderBackendApi.parseOrderRows([]), isEmpty);
  });

  test('parseOrderRows returns all valid rows', () {
    final rows = [
      {'id': '1', 'payment_method': 'cash'},
      {'id': '2', 'payment_method': 'qr'},
    ];

    final orders = SupabaseOrderBackendApi.parseOrderRows(rows);

    expect(orders.length, 2);
    expect(orders[0].payment, PaymentType.cash);
    expect(orders[1].payment, PaymentType.qr);
  });
}
