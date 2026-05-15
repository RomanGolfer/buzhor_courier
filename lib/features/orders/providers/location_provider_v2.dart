import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:buzhor_courier/core/utils/location_utils.dart';

/// Modern AsyncNotifier pattern for location management
/// Benefits over StateNotifier:
/// - Automatic loading/error states via AsyncValue
/// - Built-in error handling
/// - Cleaner async code without manual state management
class LocationNotifier extends AsyncNotifier<Position?> {
  @override
  Future<Position?> build() async {
    return LocationUtils.getCurrentPosition();
  }

  Future<void> refreshLocation() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => LocationUtils.getCurrentPosition());
  }
}

/// Modern Riverpod provider using AsyncNotifier
final locationProvider = AsyncNotifierProvider<LocationNotifier, Position?>(
  LocationNotifier.new,
);

/// Convenience selector for when you only need position (not loading state)
final locationPositionProvider = Provider<Position?>((ref) {
  return ref.watch(locationProvider).whenData((data) => data).value;
});
