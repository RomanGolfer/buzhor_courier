import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:buzhor_courier/core/utils/location_utils.dart';

class LocationState {
  final Position? position;
  final bool isLocating;
  final GpsError? error;

  const LocationState({this.position, this.isLocating = false, this.error});

  LocationState copyWith({
    Position? position,
    bool? isLocating,
    GpsError? error,
    bool clearError = false,
  }) {
    return LocationState(
      position: position ?? this.position,
      isLocating: isLocating ?? this.isLocating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState());

  Future<void> refreshLocation() async {
    state = state.copyWith(isLocating: true, clearError: true);
    final result = await LocationUtils.getCurrentPosition();
    state = LocationState(
      position: result.position,
      isLocating: false,
      error: result.error,
    );
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);
