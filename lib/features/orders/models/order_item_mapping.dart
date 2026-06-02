part of 'order_item.dart';

OrderItem _orderFromJson(Map<String, dynamic> json) {
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
    deliveryDate: _optionalDate(json['deliveryDate']),
    createdAt: _optionalDateTime(json['createdAt']),
    updatedAt: _optionalDateTime(json['updatedAt']),
  );
}

OrderItem _orderFromBackendJson(Map<String, dynamic> json) {
  final state = _deliveryStateFromBackend(json['state'] as String?);
  final markingCodes = _stringListMapFromJson(json['marking_codes']);
  final scannedItems = _intMapFromJson(json['scanned_items']);

  return OrderItem(
    id: json['id'] as String,
    orderNumber: json['order_number'] as String?,
    clientName: json['client_name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    district: json['district'] as String? ?? '',
    price: _doubleFromJson(json['price']),
    payment: _paymentTypeFromName(
      json['payment_method'] as String? ?? PaymentType.cash.name,
    ),
    bottles: json['bottles'] as int? ?? 0,
    lat: _doubleFromJson(json['lat']),
    lng: _doubleFromJson(json['lng']),
    isDone: state == OrderDeliveryState.delivered,
    deliveryState: state,
    comment: json['comment'] as String?,
    phone: json['client_phone'] as String?,
    deliveredBottles: json['delivered_bottles'] as int?,
    returnedBottles: json['returned_bottles'] as int?,
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
    deliveryDate: _optionalDate(json['delivery_date']),
    createdAt: _optionalDateTime(json['created_at']),
    updatedAt: _optionalDateTime(json['updated_at']),
  );
}

Map<String, dynamic> _orderToJson(OrderItem order) => {
  'id': order.id,
  'orderNumber': order.orderNumber,
  'clientName': order.clientName,
  'address': order.address,
  'district': order.district,
  'price': order.price,
  'payment': order.payment.name,
  'bottles': order.bottles,
  'lat': order.lat,
  'lng': order.lng,
  'isDone': order.isDone,
  'deliveryState': order.deliveryState.name,
  'comment': order.comment,
  'phone': order.phone,
  'deliveredBottles': order.deliveredBottles,
  'returnedBottles': order.returnedBottles,
  'confirmedPayment': order.confirmedPayment?.name,
  'extras': order.extras,
  'scannedItems': order.scannedItems,
  'markingCodes': order.markingCodes,
  'fiscalReceipt': order.fiscalReceipt.toJson(),
  'clientRating': order.clientRating?.toJson(),
  'deliveryComment': order.deliveryComment,
  'failureReason': order.failureReason,
  'timeSlot': order.timeSlot,
  'deliveryDate': _dateKey(order.deliveryDate),
  'createdAt': order.createdAt?.toIso8601String(),
  'updatedAt': order.updatedAt?.toIso8601String(),
};
