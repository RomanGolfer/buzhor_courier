import 'package:buzhor_courier/features/orders/models/order_item.dart';

enum OrderActionType { complete, fail, setMarkingCodes, upsert }

class OrderActionJournalEntry {
  final String id;
  final OrderActionType type;
  final String orderId;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  const OrderActionJournalEntry({
    required this.id,
    required this.type,
    required this.orderId,
    required this.createdAt,
    required this.payload,
  });

  factory OrderActionJournalEntry.complete(
    String orderId, {
    required int bottles,
    required int returnedBottles,
    required PaymentType paymentType,
    required Map<String, int> extras,
    required Map<String, int> scannedItems,
    Map<String, List<String>> markingCodes = const {},
    FiscalReceipt fiscalReceipt = const FiscalReceipt.notRequired(),
    ClientRating? clientRating,
    String? comment,
  }) {
    return OrderActionJournalEntry(
      id: _entryId(orderId, OrderActionType.complete),
      type: OrderActionType.complete,
      orderId: orderId,
      createdAt: DateTime.now(),
      payload: {
        'bottles': bottles,
        'returnedBottles': returnedBottles,
        'paymentType': paymentType.name,
        'extras': extras,
        'scannedItems': scannedItems,
        'markingCodes': markingCodes,
        'fiscalReceipt': fiscalReceipt.toJson(),
        'clientRating': clientRating?.toJson(),
        'comment': comment,
      },
    );
  }

  factory OrderActionJournalEntry.fail(
    String orderId, {
    required String reason,
  }) {
    return OrderActionJournalEntry(
      id: _entryId(orderId, OrderActionType.fail),
      type: OrderActionType.fail,
      orderId: orderId,
      createdAt: DateTime.now(),
      payload: {'reason': reason},
    );
  }

  factory OrderActionJournalEntry.setMarkingCodes(
    String orderId, {
    required Map<String, List<String>> markingCodes,
  }) {
    return OrderActionJournalEntry(
      id: _entryId(orderId, OrderActionType.setMarkingCodes),
      type: OrderActionType.setMarkingCodes,
      orderId: orderId,
      createdAt: DateTime.now(),
      payload: {
        'markingCodes': markingCodes,
        'scannedItems': _countsFromMarkingCodes(markingCodes),
      },
    );
  }

  factory OrderActionJournalEntry.resetMarkingCodes(
    String orderId, {
    required Map<String, List<String>> expectedMarkingCodes,
  }) {
    return OrderActionJournalEntry(
      id: _entryId(orderId, OrderActionType.setMarkingCodes),
      type: OrderActionType.setMarkingCodes,
      orderId: orderId,
      createdAt: DateTime.now(),
      payload: {
        'resetMarkingCodes': true,
        'expectedMarkingCodes': expectedMarkingCodes,
        'markingCodes': const <String, List<String>>{},
        'scannedItems': const <String, int>{},
      },
    );
  }

  factory OrderActionJournalEntry.upsert(OrderItem order) {
    return OrderActionJournalEntry(
      id: _entryId(order.id, OrderActionType.upsert),
      type: OrderActionType.upsert,
      orderId: order.id,
      createdAt: DateTime.now(),
      payload: {'order': order.toJson()},
    );
  }

  factory OrderActionJournalEntry.fromJson(Map<String, dynamic> json) {
    return OrderActionJournalEntry(
      id: json['id'] as String,
      type: _typeFromName(json['type'] as String),
      orderId: json['orderId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'orderId': orderId,
      'createdAt': createdAt.toIso8601String(),
      'payload': payload,
    };
  }
}

String _entryId(String orderId, OrderActionType type) {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  return '${type.name}-$orderId-$timestamp';
}

OrderActionType _typeFromName(String name) {
  return OrderActionType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => OrderActionType.upsert,
  );
}

Map<String, int> _countsFromMarkingCodes(
  Map<String, List<String>> markingCodes,
) {
  if (markingCodes.isEmpty) return const {};
  return markingCodes.map((key, codes) => MapEntry(key, codes.length));
}
