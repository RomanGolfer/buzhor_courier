import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:buzhor_courier/core/backend/supabase_backend.dart';
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
    if (result.position != null) {
      unawaited(_reportLocation(result.position!));
    }
  }

  Future<void> _reportLocation(Position position) async {
    final client = SupabaseBackend.client;
    if (client == null || SupabaseBackend.currentSession == null) return;
    try {
      await SupabaseBackend.refreshSessionIfNeeded();
      await client.rpc(
        'report_courier_location',
        params: {
          'p_lat': position.latitude,
          'p_lng': position.longitude,
          'p_accuracy_m': position.accuracy,
        },
      );
    } on Object {
      // GPS remains useful to the driver even if the optional dispatcher update fails.
    }
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);
