enum PaymentType { card, cash, qr, online, contract }

enum OrderDeliveryState { active, delivered, failed }

const Object _copyWithSentinel = Object();

class OrderItem {
  final String id;
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
  final String? deliveryComment;
  final String? failureReason;

  const OrderItem({
    required this.id,
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
    this.deliveryComment,
    this.failureReason,
  });

  final bool isDone;

  bool get isClosed => effectiveDeliveryState != OrderDeliveryState.active;
  bool get isFailed => effectiveDeliveryState == OrderDeliveryState.failed;

  OrderDeliveryState get effectiveDeliveryState {
    if (deliveryState != OrderDeliveryState.active) return deliveryState;
    return isDone ? OrderDeliveryState.delivered : OrderDeliveryState.active;
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
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
      scannedItems: _intMapFromJson(json['scannedItems']),
      deliveryComment: json['deliveryComment'] as String?,
      failureReason: json['failureReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
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
    'deliveryComment': deliveryComment,
    'failureReason': failureReason,
  };

  OrderItem copyWith({
    bool? isDone,
    OrderDeliveryState? deliveryState,
    double? price,
    PaymentType? payment,
    Object? comment = _copyWithSentinel,
    Object? phone = _copyWithSentinel,
    Object? deliveredBottles = _copyWithSentinel,
    Object? returnedBottles = _copyWithSentinel,
    Object? confirmedPayment = _copyWithSentinel,
    Map<String, int>? extras,
    Map<String, int>? scannedItems,
    Object? deliveryComment = _copyWithSentinel,
    Object? failureReason = _copyWithSentinel,
  }) => OrderItem(
    id: id,
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
    scannedItems: scannedItems ?? this.scannedItems,
    deliveryComment: _copyNullable(deliveryComment, this.deliveryComment),
    failureReason: _copyNullable(failureReason, this.failureReason),
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

Map<String, int> _intMapFromJson(Object? value) {
  if (value == null) return const {};
  final map = value as Map<String, dynamic>;
  return map.map((key, value) => MapEntry(key, (value as num).toInt()));
}
