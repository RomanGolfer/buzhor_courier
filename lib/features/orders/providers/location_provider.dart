import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:buzhor_courier/core/utils/location_utils.dart';

class LocationState {
  final Position? position;
  final bool isLocating;

  const LocationState({this.position, this.isLocating = false});

  LocationState copyWith({Position? position, bool? isLocating}) {
    return LocationState(
      position: position ?? this.position,
      isLocating: isLocating ?? this.isLocating,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState());

  Future<void> refreshLocation() async {
    state = state.copyWith(isLocating: true);
    final position = await LocationUtils.getCurrentPosition();
    state = state.copyWith(position: position, isLocating: false);
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);
