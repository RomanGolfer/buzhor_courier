import 'package:buzhor_courier/features/orders/services/order_pricing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates current water and extra prices', () {
    expect(OrderPricingService.waterTotal(1), 400);
    expect(OrderPricingService.waterTotal(2), 600);
    expect(OrderPricingService.waterTotal(3), 900);
    expect(
      OrderPricingService.orderTotal(
        bottles: 2,
        extras: const {
          OrderPricingService.mechanicalPumpName: 1,
          OrderPricingService.petBottleDepositName: 1,
        },
      ),
      1500,
    );
  });
}
