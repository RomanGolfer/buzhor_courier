part of '../order_detail_screen.dart';

class _DeliveryConfirmation {
  final int returnedBottles;
  final Map<String, int> scannedItems;
  final Map<String, List<String>> markingCodes;
  final PaymentType paymentType;
  final ClientRating clientRating;
  final String? comment;

  const _DeliveryConfirmation({
    required this.returnedBottles,
    required this.scannedItems,
    required this.markingCodes,
    required this.paymentType,
    required this.clientRating,
    required this.comment,
  });
}

class _FailureConfirmation {
  final String reason;

  const _FailureConfirmation({required this.reason});
}
