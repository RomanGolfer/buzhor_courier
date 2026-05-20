import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/services/order_pricing_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackendPricingConfig {
  final int singleBottlePrice;
  final int multiBottlePrice;
  final int mechanicalPumpPrice;
  final int petBottleDepositPrice;

  const BackendPricingConfig({
    required this.singleBottlePrice,
    required this.multiBottlePrice,
    required this.mechanicalPumpPrice,
    required this.petBottleDepositPrice,
  });

  factory BackendPricingConfig.fromJson(Map<String, dynamic> json) {
    final water = json['water'] as Map<String, dynamic>? ?? const {};
    final extras = json['extras'] as Map<String, dynamic>? ?? const {};

    return BackendPricingConfig(
      singleBottlePrice:
          (water['singleBottle'] as num?)?.toInt() ??
          OrderPricingService.singleBottlePrice,
      multiBottlePrice:
          (water['multiBottle'] as num?)?.toInt() ??
          OrderPricingService.multiBottlePrice,
      mechanicalPumpPrice:
          (extras['mechanicalPump'] as num?)?.toInt() ??
          OrderPricingService.mechanicalPumpPrice,
      petBottleDepositPrice:
          (extras['petBottleDeposit'] as num?)?.toInt() ??
          OrderPricingService.petBottleDepositPrice,
    );
  }

  static const fallback = BackendPricingConfig(
    singleBottlePrice: OrderPricingService.singleBottlePrice,
    multiBottlePrice: OrderPricingService.multiBottlePrice,
    mechanicalPumpPrice: OrderPricingService.mechanicalPumpPrice,
    petBottleDepositPrice: OrderPricingService.petBottleDepositPrice,
  );
}

class BackendAppConfig {
  final BackendPricingConfig pricing;
  final String dispatcherPhone;
  final int syncPollIntervalSeconds;
  final int maxRetryBackoffSeconds;

  const BackendAppConfig({
    required this.pricing,
    required this.dispatcherPhone,
    required this.syncPollIntervalSeconds,
    required this.maxRetryBackoffSeconds,
  });

  static const fallback = BackendAppConfig(
    pricing: BackendPricingConfig.fallback,
    dispatcherPhone: '+79385358777',
    syncPollIntervalSeconds: 60,
    maxRetryBackoffSeconds: 900,
  );
}

class BackendAppConfigRepository {
  const BackendAppConfigRepository();

  Future<BackendAppConfig> fetch() async {
    final client = SupabaseBackend.client;
    if (client == null || client.auth.currentSession == null) {
      return BackendAppConfig.fallback;
    }

    try {
      final rows = await client.from('app_config').select('key,value').inFilter(
        'key',
        ['pricing', 'dispatcher_contact', 'sync'],
      );

      final values = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final key = row['key'] as String?;
        final value = row['value'];
        if (key != null && value is Map<String, dynamic>) {
          values[key] = value;
        }
      }

      final dispatcher = values['dispatcher_contact'];
      final sync = values['sync'];

      return BackendAppConfig(
        pricing: BackendPricingConfig.fromJson(values['pricing'] ?? const {}),
        dispatcherPhone:
            dispatcher?['phone'] as String? ??
            BackendAppConfig.fallback.dispatcherPhone,
        syncPollIntervalSeconds:
            (sync?['pollIntervalSeconds'] as num?)?.toInt() ??
            BackendAppConfig.fallback.syncPollIntervalSeconds,
        maxRetryBackoffSeconds:
            (sync?['maxRetryBackoffSeconds'] as num?)?.toInt() ??
            BackendAppConfig.fallback.maxRetryBackoffSeconds,
      );
    } catch (_) {
      return BackendAppConfig.fallback;
    }
  }
}

final backendAppConfigRepositoryProvider = Provider<BackendAppConfigRepository>(
  (ref) => const BackendAppConfigRepository(),
);

final backendAppConfigProvider = FutureProvider<BackendAppConfig>((ref) {
  return ref.watch(backendAppConfigRepositoryProvider).fetch();
});
