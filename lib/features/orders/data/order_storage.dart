import 'dart:convert';

import 'package:buzhor_courier/features/orders/data/order_action_journal.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class OrderStorage {
  Future<List<OrderItem>?> loadOrders();
  Future<void> saveOrders(List<OrderItem> orders);
  Future<List<OrderActionJournalEntry>> loadActionJournal();
  Future<void> appendActionJournalEntry(OrderActionJournalEntry entry);
  Future<void> clearActionJournal();
  Future<List<OrderSyncOperation>> loadSyncOperations();
  Future<void> appendSyncOperation(OrderSyncOperation operation);
  Future<void> saveSyncOperations(List<OrderSyncOperation> operations);
}

class SharedPreferencesOrderStorage implements OrderStorage {
  static const _ordersKey = 'orders_cache_v2';
  static const _actionJournalKey = 'orders_action_journal_v1';
  static const _syncOperationsKey = 'orders_sync_operations_v1';

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

  @override
  Future<List<OrderActionJournalEntry>> loadActionJournal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_actionJournalKey);
    if (raw == null) return const [];

    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map(
            (item) =>
                OrderActionJournalEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> appendActionJournalEntry(OrderActionJournalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadActionJournal();
    final raw = jsonEncode([
      ...entries.map((entry) => entry.toJson()),
      entry.toJson(),
    ]);
    await prefs.setString(_actionJournalKey, raw);
  }

  @override
  Future<void> clearActionJournal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_actionJournalKey);
  }

  @override
  Future<List<OrderSyncOperation>> loadSyncOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncOperationsKey);
    if (raw == null) return const [];

    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map(
            (item) => OrderSyncOperation.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> appendSyncOperation(OrderSyncOperation operation) async {
    final prefs = await SharedPreferences.getInstance();
    final operations = await loadSyncOperations();
    final raw = jsonEncode([
      ...operations.map((operation) => operation.toJson()),
      operation.toJson(),
    ]);
    await prefs.setString(_syncOperationsKey, raw);
  }

  @override
  Future<void> saveSyncOperations(List<OrderSyncOperation> operations) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(operations.map((op) => op.toJson()).toList());
    await prefs.setString(_syncOperationsKey, raw);
  }
}
