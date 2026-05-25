part of '../order_detail_screen.dart';

String _paymentLabel(PaymentType type) => switch (type) {
  PaymentType.card => 'Картой курьеру',
  PaymentType.cash => 'Наличные',
  PaymentType.qr => 'Онлайн оплата',
  PaymentType.online => 'Оплачено',
  PaymentType.contract => 'По договору',
};

String _fiscalReceiptLabel(FiscalReceiptStatus status) => switch (status) {
  FiscalReceiptStatus.notRequired => 'Не требуется',
  FiscalReceiptStatus.pending => 'Ожидает фискализации',
  FiscalReceiptStatus.issued => 'Чек выдан',
  FiscalReceiptStatus.failed => 'Ошибка чека',
  FiscalReceiptStatus.needsReview => 'Нужна проверка',
};
