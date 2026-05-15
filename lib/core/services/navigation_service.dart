import 'package:url_launcher/url_launcher.dart';

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
}
