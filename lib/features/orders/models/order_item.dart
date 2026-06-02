part 'client_rating.dart';
part 'fiscal_receipt.dart';
part 'order_delivery_state.dart';
part 'order_item_helpers.dart';
part 'order_item_mapping.dart';
part 'payment_type.dart';

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
  final DateTime? deliveryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.deliveryDate,
    this.createdAt,
    this.updatedAt,
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

  factory OrderItem.fromJson(Map<String, dynamic> json) => _orderFromJson(json);

  factory OrderItem.fromBackendJson(Map<String, dynamic> json) {
    return _orderFromBackendJson(json);
  }

  Map<String, dynamic> toJson() => _orderToJson(this);

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
    Object? deliveryDate = _copyWithSentinel,
    Object? createdAt = _copyWithSentinel,
    Object? updatedAt = _copyWithSentinel,
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
    deliveryDate: _copyNullable(deliveryDate, this.deliveryDate),
    createdAt: _copyNullable(createdAt, this.createdAt),
    updatedAt: _copyNullable(updatedAt, this.updatedAt),
  );
}
