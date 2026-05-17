import 'package:buzhor_courier/features/orders/models/order_item.dart';

enum PaymentCheckStatus { paid, pending, unavailable }

class PaymentStatusCheck {
  final PaymentCheckStatus status;
  final String message;

  const PaymentStatusCheck({required this.status, required this.message});
}

class PaymentStatusService {
  PaymentStatusService._();

  static Future<PaymentStatusCheck> checkPayment(OrderItem order) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const PaymentStatusCheck(
      status: PaymentCheckStatus.unavailable,
      message: 'Проверка оплаты пока не подключена',
    );
  }
}
