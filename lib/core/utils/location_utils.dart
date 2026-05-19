import 'package:geolocator/geolocator.dart';

enum GpsError {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class GpsResult {
  final Position? position;
  final GpsError? error;
  const GpsResult({this.position, this.error});
}

class LocationUtils {
  static Future<GpsResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GpsResult(error: GpsError.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const GpsResult(error: GpsError.permissionDeniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const GpsResult(error: GpsError.permissionDenied);
      }

      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw Exception('GPS timeout'),
          );
      return GpsResult(position: position);
    } on Exception catch (e) {
      if (e.toString().contains('timeout')) {
        return const GpsResult(error: GpsError.timeout);
      }
      return const GpsResult(error: GpsError.unknown);
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();
  static Future<void> openLocationSettings() =>
      Geolocator.openLocationSettings();
}
