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
      return null;
    }
    if (client.auth.currentSession == null) {
      return null;
    }

    try {
      final session = client.auth.currentSession;
      if (session == null) return null;
      if (session.isExpired) {
        await client.auth.refreshSession();
      }

      final rows = await client
          .from('orders')
          .select()
          .order('updated_at', ascending: false);
      return parseOrderRows(rows);
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch assigned orders: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static List<OrderItem> parseOrderRows(List<Map<String, dynamic>> rows) {
    final orders = <OrderItem>[];
    for (final row in rows) {
      try {
        orders.add(OrderItem.fromBackendJson(row));
      } catch (_) {}
    }
    return orders;
  }
}
