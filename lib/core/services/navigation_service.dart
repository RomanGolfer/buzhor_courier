import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class NavigationService {
  NavigationService._();

  static Future<void> openExternalRoute(double lat, double lng) async {
    final yandex = Uri.parse(
      'yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lng&zoom=12',
    );
    final yandexWeb = Uri.parse(
      'https://yandex.ru/maps/?rtext=~$lat,$lng&rtt=auto',
    );
    if (await canLaunchUrl(yandex)) {
      await launchUrl(yandex);
    } else {
      await launchUrl(yandexWeb, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openDialer(String phone) async {
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  static Future<void> openMessenger({required String phone, required String message}) async {
    final encoded = Uri.encodeComponent(message);
    // Try MAX deep link first (best-effort). If it fails, fallback to SMS.
    final candidates = [
      Uri.parse('max://chat?phone=$phone&text=$encoded'),
      Uri.parse('maxapp://chat?phone=$phone&text=$encoded'),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    // Fallback to SMS with prefilled body
    try {
      final sms = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
      if (await canLaunchUrl(sms)) {
        await launchUrl(sms);
        return;
      }
    } catch (_) {}

    // As a last resort copy message to clipboard so user can paste
    try {
      await Clipboard.setData(ClipboardData(text: message));
    } catch (_) {}
  }
}
