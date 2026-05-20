import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter/foundation.dart';

abstract class OrderBackendApi {
  Future<List<OrderItem>?> fetchAssignedOrders();
}

class SupabaseOrderBackendApi implements OrderBackendApi {
  const SupabaseOrderBackendApi();

  @override
  Future<List<OrderItem>?> fetchAssignedOrders() async {
    final client = SupabaseBackend.client;
    if (client == null) {
      debugPrint('fetchAssignedOrders: Supabase client is null');
      return null;
    }
    if (client.auth.currentSession == null) {
      debugPrint('fetchAssignedOrders: no active session');
      return null;
    }

    try {
      final rows = await client
          .from('orders')
          .select()
          .order('updated_at', ascending: false);

      final orders = <OrderItem>[];
      for (final row in rows) {
        try {
          orders.add(OrderItem.fromBackendJson(row));
        } catch (_) {}
      }
      return orders;
    } catch (e) {
      debugPrint('fetchAssignedOrders error: $e');
      return null;
    }
  }
}
