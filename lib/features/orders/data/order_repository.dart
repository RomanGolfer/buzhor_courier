import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/orders/data/sample_orders.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';

class OrderRepository {
  Future<List<OrderItem>> fetchOrders() async {
    return Future.value(sampleOrders);
  }
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(),
);
