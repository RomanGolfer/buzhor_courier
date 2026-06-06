import 'dart:convert';

import 'package:buzhor_courier/features/orders/data/order_action_journal.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_operation.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class SecureOrderStorage implements OrderStorage {
  static const _ordersKey = 'orders_cache_v2';
  static const _actionJournalKey = 'orders_action_journal_v1';
  static const _syncOperationsKey = 'orders_sync_operations_v1';

  final FlutterSecureStorage _secureStorage;

  const SecureOrderStorage({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  @override
  Future<List<OrderItem>?> loadOrders() async {
    final raw = await _readString(_ordersKey);
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
    final raw = jsonEncode(orders.map((order) => order.toJson()).toList());
    await _writeString(_ordersKey, raw);
  }

  @override
  Future<List<OrderActionJournalEntry>> loadActionJournal() async {
    final raw = await _readString(_actionJournalKey);
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
    final entries = await loadActionJournal();
    final raw = jsonEncode([
      ...entries.map((entry) => entry.toJson()),
      entry.toJson(),
    ]);
    await _writeString(_actionJournalKey, raw);
  }

  @override
  Future<void> clearActionJournal() async {
    await _deleteString(_actionJournalKey);
  }

  @override
  Future<List<OrderSyncOperation>> loadSyncOperations() async {
    final raw = await _readString(_syncOperationsKey);
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
    final operations = await loadSyncOperations();
    final raw = jsonEncode([
      ...operations.map((operation) => operation.toJson()),
      operation.toJson(),
    ]);
    await _writeString(_syncOperationsKey, raw);
  }

  @override
  Future<void> saveSyncOperations(List<OrderSyncOperation> operations) async {
    final raw = jsonEncode(operations.map((op) => op.toJson()).toList());
    await _writeString(_syncOperationsKey, raw);
  }

  Future<String?> _readString(String key) async {
    final secureValue = await _secureStorage.read(key: key);
    if (secureValue != null) return secureValue;
    return _migrateLegacyValue(key);
  }

  Future<void> _writeString(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> _deleteString(String key) async {
    await _secureStorage.delete(key: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<String?> _migrateLegacyValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(key);
    if (legacyValue == null) return null;
    await _secureStorage.write(key: key, value: legacyValue);
    await prefs.remove(key);
    return legacyValue;
  }
}

@Deprecated(
  'Use SecureOrderStorage so order data is stored in Keychain/Keystore.',
)
class SharedPreferencesOrderStorage extends SecureOrderStorage {
  const SharedPreferencesOrderStorage();
}
