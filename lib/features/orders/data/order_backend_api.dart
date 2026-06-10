import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _logBackendDebug(String message, [StackTrace? stackTrace]) {
  if (!kDebugMode) return;
  debugPrint(message);
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace);
  }
}

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

      // Do not manually refresh the session — autoRefreshToken handles it
      // transparently before each request and is more resilient on Android.
      final courierId = await _currentCourierId(client, session.user.id);
      if (courierId == null) return const [];

      final rows = await client
          .from('orders')
          .select()
          .eq('assigned_courier_id', courierId)
          .gte('delivery_date', _todayMoscowKey())
          .order('updated_at', ascending: false);
      final orders = parseOrderRows(rows);
      return _attachHistoricalClientRatings(client, orders);
    } catch (error, stackTrace) {
      _logBackendDebug('Failed to fetch assigned orders: $error', stackTrace);
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

  static Future<List<OrderItem>> _attachHistoricalClientRatings(
    SupabaseClient client,
    List<OrderItem> orders,
  ) async {
    final phones = orders
        .map((order) => _normalizePhone(order.phone))
        .whereType<String>()
        .toSet()
        .toList();
    if (phones.isEmpty) return orders;

    try {
      final ratingRows = await client
          .from('client_ratings')
          .select('client_phone_normalized, rating')
          .inFilter('client_phone_normalized', phones);
      final ratingsByPhone = <String, ({int total, int count})>{};

      for (final row in ratingRows) {
        final phone = row['client_phone_normalized'] as String?;
        final rating = (row['rating'] as num?)?.toInt();
        if (phone == null || rating == null) continue;
        final current = ratingsByPhone[phone] ?? (total: 0, count: 0);
        ratingsByPhone[phone] = (
          total: current.total + rating,
          count: current.count + 1,
        );
      }

      return orders.map((order) {
        if (order.clientRating != null) return order;
        final phone = _normalizePhone(order.phone);
        final stats = phone == null ? null : ratingsByPhone[phone];
        if (stats == null || stats.count == 0) return order;
        return order.copyWith(
          clientRating: ClientRating(
            rating: (stats.total / stats.count).round().clamp(1, 5),
          ),
        );
      }).toList();
    } catch (error) {
      _logBackendDebug('Failed to load client ratings: $error');
      return orders;
    }
  }

  static String? _normalizePhone(String? value) {
    final phone = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (phone.isEmpty) return null;
    if (phone.length == 11 && phone.startsWith('8')) {
      return '7${phone.substring(1)}';
    }
    if (phone.length == 10) return '7$phone';
    return phone;
  }

  static Future<String?> _currentCourierId(
    SupabaseClient client,
    String profileId,
  ) async {
    try {
      final row = await client
          .from('couriers')
          .select('id')
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (error) {
      _logBackendDebug('Failed to resolve courier id: $error');
      return null;
    }
  }

  static String _todayMoscowKey() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
