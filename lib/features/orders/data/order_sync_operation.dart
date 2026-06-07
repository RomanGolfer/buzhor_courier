import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:uuid/uuid.dart';

enum OrderSyncOperationType { complete, fail, setMarkingCodes }

enum OrderSyncOperationStatus {
  pending,
  inFlight,
  acked,
  rejected,
  needsReview,
}

const Object _copyWithSentinel = Object();

class OrderSyncOperation {
  final String operationId;
  final OrderSyncOperationType type;
  final OrderSyncOperationStatus status;
  final String orderId;
  final int? orderVersion;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime? ackedAt;

  const OrderSyncOperation({
    required this.operationId,
    required this.type,
    required this.status,
    required this.orderId,
    required this.orderVersion,
    required this.createdAt,
    required this.payload,
    required this.attemptCount,
    this.nextAttemptAt,
    this.lastError,
    this.ackedAt,
  });

  String get backendType {
    return switch (type) {
      OrderSyncOperationType.complete => 'complete',
      OrderSyncOperationType.fail => 'fail',
      OrderSyncOperationType.setMarkingCodes => 'set_marking_codes',
    };
  }

  factory OrderSyncOperation.setMarkingCodes(
    String orderId, {
    required Map<String, List<String>> markingCodes,
    int? orderVersion,
  }) {
    return OrderSyncOperation(
      operationId: _operationId(),
      type: OrderSyncOperationType.setMarkingCodes,
      status: OrderSyncOperationStatus.pending,
      orderId: orderId,
      orderVersion: orderVersion,
      createdAt: DateTime.now(),
      payload: {
        'markingCodes': markingCodes,
        'scannedItems': _countsFromMarkingCodes(markingCodes),
      },
      attemptCount: 0,
    );
  }

  factory OrderSyncOperation.complete(
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
    int? orderVersion,
  }) {
    return OrderSyncOperation(
      operationId: _operationId(),
      type: OrderSyncOperationType.complete,
      status: OrderSyncOperationStatus.pending,
      orderId: orderId,
      orderVersion: orderVersion,
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
      attemptCount: 0,
    );
  }

  factory OrderSyncOperation.fail(
    String orderId, {
    required String reason,
    int? orderVersion,
  }) {
    return OrderSyncOperation(
      operationId: _operationId(),
      type: OrderSyncOperationType.fail,
      status: OrderSyncOperationStatus.pending,
      orderId: orderId,
      orderVersion: orderVersion,
      createdAt: DateTime.now(),
      payload: {'reason': reason},
      attemptCount: 0,
    );
  }

  factory OrderSyncOperation.fromJson(Map<String, dynamic> json) {
    return OrderSyncOperation(
      operationId: json['operationId'] as String,
      type: _typeFromName(json['type'] as String),
      status: _statusFromName(json['status'] as String),
      orderId: json['orderId'] as String,
      orderVersion: json['orderVersion'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      attemptCount: json['attemptCount'] as int? ?? 0,
      nextAttemptAt: _optionalDateTime(json['nextAttemptAt'] as String?),
      lastError: json['lastError'] as String?,
      ackedAt: _optionalDateTime(json['ackedAt'] as String?),
    );
  }

  OrderSyncOperation copyWith({
    OrderSyncOperationStatus? status,
    int? attemptCount,
    Object? nextAttemptAt = _copyWithSentinel,
    Object? lastError = _copyWithSentinel,
    Object? ackedAt = _copyWithSentinel,
  }) {
    return OrderSyncOperation(
      operationId: operationId,
      type: type,
      status: status ?? this.status,
      orderId: orderId,
      orderVersion: orderVersion,
      createdAt: createdAt,
      payload: payload,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: _copyNullable(nextAttemptAt, this.nextAttemptAt),
      lastError: _copyNullable(lastError, this.lastError),
      ackedAt: _copyNullable(ackedAt, this.ackedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operationId': operationId,
      'type': type.name,
      'status': status.name,
      'orderId': orderId,
      'orderVersion': orderVersion,
      'createdAt': createdAt.toIso8601String(),
      'payload': payload,
      'attemptCount': attemptCount,
      'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      'lastError': lastError,
      'ackedAt': ackedAt?.toIso8601String(),
    };
  }
}

T? _copyNullable<T>(Object? value, T? fallback) {
  if (identical(value, _copyWithSentinel)) return fallback;
  return value as T?;
}

String _operationId() => const Uuid().v4();

OrderSyncOperationType _typeFromName(String name) {
  return OrderSyncOperationType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => OrderSyncOperationType.complete,
  );
}

OrderSyncOperationStatus _statusFromName(String name) {
  return OrderSyncOperationStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => OrderSyncOperationStatus.pending,
  );
}

DateTime? _optionalDateTime(String? value) {
  if (value == null) return null;
  return DateTime.parse(value);
}

Map<String, int> _countsFromMarkingCodes(
  Map<String, List<String>> markingCodes,
) {
  if (markingCodes.isEmpty) return const {};
  return markingCodes.map((key, codes) => MapEntry(key, codes.length));
}
