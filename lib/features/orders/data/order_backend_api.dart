import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';

abstract class OrderBackendApi {
  Future<List<OrderItem>?> fetchAssignedOrders();
}

class SupabaseOrderBackendApi implements OrderBackendApi {
  const SupabaseOrderBackendApi();

  @override
  Future<List<OrderItem>?> fetchAssignedOrders() async {
    final client = SupabaseBackend.client;
    if (client == null || client.auth.currentSession == null) return null;

    try {
      final rows = await client
          .from('orders')
          .select()
          .order('updated_at', ascending: false);

      return rows.map((row) => OrderItem.fromBackendJson(row)).toList();
    } catch (_) {
      return null;
    }
  }
}
