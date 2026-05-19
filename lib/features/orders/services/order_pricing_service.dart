class OrderPricingService {
  static const singleBottlePrice = 400;
  static const multiBottlePrice = 300;
  static const mechanicalPumpPrice = 500;
  static const petBottleDepositPrice = 400;

  static const mechanicalPumpName = 'Помпа механическая';
  static const petBottleDepositName = 'Тара ПЭТ';

  static double waterTotal(int bottles) {
    if (bottles <= 0) return 0;
    if (bottles == 1) return singleBottlePrice.toDouble();
    return (bottles * multiBottlePrice).toDouble();
  }

  static double extraTotal(Map<String, int> extras) {
    return extras.entries.fold<double>(
      0,
      (sum, entry) => sum + extraUnitPrice(entry.key) * entry.value,
    );
  }

  static double orderTotal({
    required int bottles,
    required Map<String, int> extras,
  }) {
    return waterTotal(bottles) + extraTotal(extras);
  }

  static int extraUnitPrice(String name) {
    return switch (name) {
      mechanicalPumpName || 'Помпа' => mechanicalPumpPrice,
      petBottleDepositName || 'Тара 19л' => petBottleDepositPrice,
      _ => 0,
    };
  }
}
