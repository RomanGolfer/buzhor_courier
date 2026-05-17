enum PaymentType { card, cash, qr, online, contract }

enum OrderDeliveryState { active, delivered, failed }

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

  OrderItem copyWith({
    bool? isDone,
    OrderDeliveryState? deliveryState,
    int? deliveredBottles,
    int? returnedBottles,
    PaymentType? confirmedPayment,
    Map<String, int>? extras,
    Map<String, int>? scannedItems,
    String? deliveryComment,
    String? failureReason,
  }) => OrderItem(
    id: id,
    clientName: clientName,
    address: address,
    district: district,
    price: price,
    payment: payment,
    bottles: bottles,
    lat: lat,
    lng: lng,
    isDone: isDone ?? this.isDone,
    deliveryState: deliveryState ?? this.deliveryState,
    comment: comment,
    phone: phone,
    deliveredBottles: deliveredBottles ?? this.deliveredBottles,
    returnedBottles: returnedBottles ?? this.returnedBottles,
    confirmedPayment: confirmedPayment ?? this.confirmedPayment,
    extras: extras ?? this.extras,
    scannedItems: scannedItems ?? this.scannedItems,
    deliveryComment: deliveryComment ?? this.deliveryComment,
    failureReason: failureReason ?? this.failureReason,
  );
}
