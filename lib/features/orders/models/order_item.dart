enum PaymentType { card, cash, qr, online, contract }

enum OrderDeliveryState { active, delivered, failed }

enum FiscalReceiptStatus { notRequired, pending, issued, failed, needsReview }

const Object _copyWithSentinel = Object();

class FiscalReceipt {
  final FiscalReceiptStatus status;
  final String? operationId;
  final String? provider;
  final String? receiptUrl;
  final String? fiscalDocumentNumber;
  final String? fiscalDriveNumber;
  final String? fiscalSign;
  final DateTime? issuedAt;
  final String? error;

  const FiscalReceipt({
    required this.status,
    this.operationId,
    this.provider,
    this.receiptUrl,
    this.fiscalDocumentNumber,
    this.fiscalDriveNumber,
    this.fiscalSign,
    this.issuedAt,
    this.error,
  });

  const FiscalReceipt.notRequired()
    : status = FiscalReceiptStatus.notRequired,
      operationId = null,
      provider = null,
      receiptUrl = null,
      fiscalDocumentNumber = null,
      fiscalDriveNumber = null,
      fiscalSign = null,
      issuedAt = null,
      error = null;

  const FiscalReceipt.pending({required this.operationId})
    : status = FiscalReceiptStatus.pending,
      provider = null,
      receiptUrl = null,
      fiscalDocumentNumber = null,
      fiscalDriveNumber = null,
      fiscalSign = null,
      issuedAt = null,
      error = null;

  factory FiscalReceipt.fromJson(Object? value) {
    if (value is! Map) return const FiscalReceipt.notRequired();
    final json = Map<String, dynamic>.from(value);
    return FiscalReceipt(
      status: _fiscalReceiptStatusFromName(json['status'] as String?),
      operationId:
          json['operationId'] as String? ?? json['operation_id'] as String?,
      provider: json['provider'] as String?,
      receiptUrl:
          json['receiptUrl'] as String? ?? json['receipt_url'] as String?,
      fiscalDocumentNumber:
          json['fiscalDocumentNumber'] as String? ??
          json['fiscal_document_number'] as String?,
      fiscalDriveNumber:
          json['fiscalDriveNumber'] as String? ??
          json['fiscal_drive_number'] as String?,
      fiscalSign:
          json['fiscalSign'] as String? ?? json['fiscal_sign'] as String?,
      issuedAt: _optionalDateTime(json['issuedAt'] ?? json['issued_at']),
      error: json['error'] as String?,
    );
  }

  bool get isRequired => status != FiscalReceiptStatus.notRequired;

  Map<String, dynamic> toJson() => {
    'status': status.backendName,
    'operationId': operationId,
    'provider': provider,
    'receiptUrl': receiptUrl,
    'fiscalDocumentNumber': fiscalDocumentNumber,
    'fiscalDriveNumber': fiscalDriveNumber,
    'fiscalSign': fiscalSign,
    'issuedAt': issuedAt?.toIso8601String(),
    'error': error,
  };

  FiscalReceipt copyWith({
    FiscalReceiptStatus? status,
    Object? operationId = _copyWithSentinel,
    Object? provider = _copyWithSentinel,
    Object? receiptUrl = _copyWithSentinel,
    Object? fiscalDocumentNumber = _copyWithSentinel,
    Object? fiscalDriveNumber = _copyWithSentinel,
    Object? fiscalSign = _copyWithSentinel,
    Object? issuedAt = _copyWithSentinel,
    Object? error = _copyWithSentinel,
  }) {
    return FiscalReceipt(
      status: status ?? this.status,
      operationId: _copyNullable(operationId, this.operationId),
      provider: _copyNullable(provider, this.provider),
      receiptUrl: _copyNullable(receiptUrl, this.receiptUrl),
      fiscalDocumentNumber: _copyNullable(
        fiscalDocumentNumber,
        this.fiscalDocumentNumber,
      ),
      fiscalDriveNumber: _copyNullable(
        fiscalDriveNumber,
        this.fiscalDriveNumber,
      ),
      fiscalSign: _copyNullable(fiscalSign, this.fiscalSign),
      issuedAt: _copyNullable(issuedAt, this.issuedAt),
      error: _copyNullable(error, this.error),
    );
  }
}

class ClientRating {
  final int rating;
  final DateTime? ratedAt;

  const ClientRating({required this.rating, this.ratedAt})
    : assert(rating >= 1 && rating <= 5);

  static ClientRating? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final rawRating = (json['rating'] as num?)?.toInt();
    if (rawRating == null) return null;
    return ClientRating(
      rating: rawRating.clamp(1, 5).toInt(),
      ratedAt: _optionalDateTime(json['ratedAt'] ?? json['rated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'rating': rating,
    'ratedAt': ratedAt?.toIso8601String(),
  };
}

extension FiscalReceiptStatusName on FiscalReceiptStatus {
  String get backendName {
    return switch (this) {
      FiscalReceiptStatus.notRequired => 'not_required',
      FiscalReceiptStatus.pending => 'pending',
      FiscalReceiptStatus.issued => 'issued',
      FiscalReceiptStatus.failed => 'failed',
      FiscalReceiptStatus.needsReview => 'needs_review',
    };
  }
}

class OrderItem {
  final String id;
  final String? orderNumber;
  final String clientName;
  final String address;
  final String district;
  final double price;
  final PaymentType payment;
  final int bottles;
  final OrderDeliveryState deliveryState;
  final double lat;
  final double lng;
  final String? comment;
  final String? phone;
  final int? deliveredBottles;
  final int? returnedBottles;
  final PaymentType? confirmedPayment;
  final Map<String, int> extras;
  final Map<String, int> scannedItems;
  final Map<String, List<String>> markingCodes;
  final FiscalReceipt fiscalReceipt;
  final ClientRating? clientRating;
  final String? deliveryComment;
  final String? failureReason;
  final String? timeSlot;

  const OrderItem({
    required this.id,
    this.orderNumber,
    required this.clientName,
    required this.address,
    required this.district,
    required this.price,
    required this.payment,
    required this.bottles,
    required this.lat,
    required this.lng,
    this.isDone = false,
    this.deliveryState = OrderDeliveryState.active,
    this.comment,
    this.phone,
    this.deliveredBottles,
    this.returnedBottles,
    this.confirmedPayment,
    this.extras = const {},
    this.scannedItems = const {},
    this.markingCodes = const {},
    this.fiscalReceipt = const FiscalReceipt.notRequired(),
    this.clientRating,
    this.deliveryComment,
    this.failureReason,
    this.timeSlot,
  });

  final bool isDone;

  String get displayId => orderNumber ?? id;

  bool get isClosed => effectiveDeliveryState != OrderDeliveryState.active;
  bool get isFailed => effectiveDeliveryState == OrderDeliveryState.failed;
  bool get hasCoordinates =>
      lat.isFinite &&
      lng.isFinite &&
      lat.abs() <= 90 &&
      lng.abs() <= 180 &&
      !(lat == 0 && lng == 0);

  int scannedCountFor(String itemId) {
    final codes = markingCodes[itemId];
    if (codes != null && codes.isNotEmpty) return codes.length;
    return scannedItems[itemId] ?? 0;
  }

  OrderDeliveryState get effectiveDeliveryState {
    if (deliveryState != OrderDeliveryState.active) return deliveryState;
    return isDone ? OrderDeliveryState.delivered : OrderDeliveryState.active;
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final markingCodes = _stringListMapFromJson(json['markingCodes']);
    final scannedItems = _intMapFromJson(json['scannedItems']);

    return OrderItem(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String?,
      clientName: json['clientName'] as String,
      address: json['address'] as String,
      district: json['district'] as String,
      price: (json['price'] as num).toDouble(),
      payment: _paymentTypeFromName(json['payment'] as String),
      bottles: json['bottles'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      isDone: json['isDone'] as bool? ?? false,
      deliveryState: _deliveryStateFromName(
        json['deliveryState'] as String? ?? OrderDeliveryState.active.name,
      ),
      comment: json['comment'] as String?,
      phone: json['phone'] as String?,
      deliveredBottles: json['deliveredBottles'] as int?,
      returnedBottles: json['returnedBottles'] as int?,
      confirmedPayment: _optionalPaymentTypeFromName(
        json['confirmedPayment'] as String?,
      ),
      extras: _intMapFromJson(json['extras']),
      scannedItems: scannedItems.isEmpty
          ? _countsFromMarkingCodes(markingCodes)
          : scannedItems,
      markingCodes: markingCodes,
      fiscalReceipt: FiscalReceipt.fromJson(json['fiscalReceipt']),
      clientRating: ClientRating.fromJson(json['clientRating']),
      deliveryComment: json['deliveryComment'] as String?,
      failureReason: json['failureReason'] as String?,
      timeSlot: json['timeSlot'] as String?,
    );
  }

  factory OrderItem.fromBackendJson(Map<String, dynamic> json) {
    final state = _deliveryStateFromBackend(json['state'] as String?);
    final deliveredBottles = json['delivered_bottles'] as int?;
    final returnedBottles = json['returned_bottles'] as int?;
    final markingCodes = _stringListMapFromJson(json['marking_codes']);
    final scannedItems = _intMapFromJson(json['scanned_items']);

    return OrderItem(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String?,
      clientName: json['client_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      district: json['district'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      payment: _paymentTypeFromName(
        json['payment_method'] as String? ?? PaymentType.cash.name,
      ),
      bottles: json['bottles'] as int? ?? 0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      isDone: state == OrderDeliveryState.delivered,
      deliveryState: state,
      comment: json['comment'] as String?,
      phone: json['client_phone'] as String?,
      deliveredBottles: deliveredBottles,
      returnedBottles: returnedBottles,
      confirmedPayment: _optionalPaymentTypeFromName(
        json['confirmed_payment'] as String?,
      ),
      extras: _intMapFromJson(json['extras']),
      scannedItems: scannedItems.isEmpty
          ? _countsFromMarkingCodes(markingCodes)
          : scannedItems,
      markingCodes: markingCodes,
      fiscalReceipt: FiscalReceipt.fromJson(json['fiscal_receipt']),
      clientRating: ClientRating.fromJson(json['client_rating']),
      deliveryComment: json['delivery_comment'] as String?,
      failureReason: json['failure_reason'] as String?,
      timeSlot: json['time_slot'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderNumber': orderNumber,
    'clientName': clientName,
    'address': address,
    'district': district,
    'price': price,
    'payment': payment.name,
    'bottles': bottles,
    'lat': lat,
    'lng': lng,
    'isDone': isDone,
    'deliveryState': deliveryState.name,
    'comment': comment,
    'phone': phone,
    'deliveredBottles': deliveredBottles,
    'returnedBottles': returnedBottles,
    'confirmedPayment': confirmedPayment?.name,
    'extras': extras,
    'scannedItems': scannedItems,
    'markingCodes': markingCodes,
    'fiscalReceipt': fiscalReceipt.toJson(),
    'clientRating': clientRating?.toJson(),
    'deliveryComment': deliveryComment,
    'failureReason': failureReason,
    'timeSlot': timeSlot,
  };

  OrderItem copyWith({
    bool? isDone,
    OrderDeliveryState? deliveryState,
    double? price,
    PaymentType? payment,
    Object? orderNumber = _copyWithSentinel,
    Object? comment = _copyWithSentinel,
    Object? phone = _copyWithSentinel,
    Object? deliveredBottles = _copyWithSentinel,
    Object? returnedBottles = _copyWithSentinel,
    Object? confirmedPayment = _copyWithSentinel,
    Map<String, int>? extras,
    Map<String, int>? scannedItems,
    Map<String, List<String>>? markingCodes,
    FiscalReceipt? fiscalReceipt,
    Object? clientRating = _copyWithSentinel,
    Object? deliveryComment = _copyWithSentinel,
    Object? failureReason = _copyWithSentinel,
    Object? timeSlot = _copyWithSentinel,
  }) => OrderItem(
    id: id,
    orderNumber: _copyNullable(orderNumber, this.orderNumber),
    clientName: clientName,
    address: address,
    district: district,
    price: price ?? this.price,
    payment: payment ?? this.payment,
    bottles: bottles,
    lat: lat,
    lng: lng,
    isDone: isDone ?? this.isDone,
    deliveryState: deliveryState ?? this.deliveryState,
    comment: _copyNullable(comment, this.comment),
    phone: _copyNullable(phone, this.phone),
    deliveredBottles: _copyNullable(deliveredBottles, this.deliveredBottles),
    returnedBottles: _copyNullable(returnedBottles, this.returnedBottles),
    confirmedPayment: _copyNullable(confirmedPayment, this.confirmedPayment),
    extras: extras ?? this.extras,
    scannedItems:
        scannedItems ??
        (markingCodes == null
            ? this.scannedItems
            : _countsFromMarkingCodes(markingCodes)),
    markingCodes: markingCodes ?? this.markingCodes,
    fiscalReceipt: fiscalReceipt ?? this.fiscalReceipt,
    clientRating: _copyNullable(clientRating, this.clientRating),
    deliveryComment: _copyNullable(deliveryComment, this.deliveryComment),
    failureReason: _copyNullable(failureReason, this.failureReason),
    timeSlot: _copyNullable(timeSlot, this.timeSlot),
  );
}

T? _copyNullable<T>(Object? value, T? fallback) {
  if (identical(value, _copyWithSentinel)) return fallback;
  return value as T?;
}

PaymentType _paymentTypeFromName(String name) {
  return PaymentType.values.byName(name);
}

PaymentType? _optionalPaymentTypeFromName(String? name) {
  if (name == null) return null;
  return _paymentTypeFromName(name);
}

OrderDeliveryState _deliveryStateFromName(String name) {
  return OrderDeliveryState.values.byName(name);
}

OrderDeliveryState _deliveryStateFromBackend(String? name) {
  return switch (name) {
    'delivered' => OrderDeliveryState.delivered,
    'failed' || 'cancelled' => OrderDeliveryState.failed,
    _ => OrderDeliveryState.active,
  };
}

Map<String, int> _intMapFromJson(Object? value) {
  if (value == null) return const {};
  final map = value as Map<String, dynamic>;
  return map.map((key, value) => MapEntry(key, (value as num).toInt()));
}

Map<String, List<String>> _stringListMapFromJson(Object? value) {
  if (value == null) return const {};
  final map = value as Map<String, dynamic>;
  return map.map(
    (key, value) =>
        MapEntry(key, (value as List).map((item) => item.toString()).toList()),
  );
}

Map<String, int> _countsFromMarkingCodes(
  Map<String, List<String>> markingCodes,
) {
  if (markingCodes.isEmpty) return const {};
  return markingCodes.map((key, codes) => MapEntry(key, codes.length));
}

FiscalReceiptStatus _fiscalReceiptStatusFromName(String? name) {
  return switch (name) {
    'notRequired' || 'not_required' => FiscalReceiptStatus.notRequired,
    'pending' => FiscalReceiptStatus.pending,
    'issued' => FiscalReceiptStatus.issued,
    'failed' => FiscalReceiptStatus.failed,
    'needsReview' || 'needs_review' => FiscalReceiptStatus.needsReview,
    _ => FiscalReceiptStatus.notRequired,
  };
}

DateTime? _optionalDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
