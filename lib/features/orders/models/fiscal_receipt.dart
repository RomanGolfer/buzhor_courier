part of 'order_item.dart';

enum FiscalReceiptStatus { notRequired, pending, issued, failed, needsReview }

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
