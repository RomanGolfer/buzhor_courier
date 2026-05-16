enum PaymentType { card, cash, qr, online, contract }

class OrderItem {
  final String id;
  final String clientName;
  final String address;
  final String district;
  final double price;
  final PaymentType payment;
  final int bottles;
  final bool isDone;
  final double lat;
  final double lng;
  final String? comment;
  final String? phone;

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
    this.comment,
    this.phone,
  });

  OrderItem copyWith({bool? isDone}) => OrderItem(
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
    comment: comment,
    phone: phone,
  );
}
