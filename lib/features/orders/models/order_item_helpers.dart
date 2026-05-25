part of 'order_item.dart';

const Object _copyWithSentinel = Object();

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

DateTime? _optionalDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
