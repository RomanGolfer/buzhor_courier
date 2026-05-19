import 'dart:convert';

import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class OrderStorage {
  Future<List<OrderItem>?> loadOrders();
  Future<void> saveOrders(List<OrderItem> orders);
}

class SharedPreferencesOrderStorage implements OrderStorage {
  static const _ordersKey = 'orders_cache_v2';

  const SharedPreferencesOrderStorage();

  @override
  Future<List<OrderItem>?> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ordersKey);
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveOrders(List<OrderItem> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(orders.map((order) => order.toJson()).toList());
    await prefs.setString(_ordersKey, raw);
  }
}
