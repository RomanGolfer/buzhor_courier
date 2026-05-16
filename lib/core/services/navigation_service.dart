import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  NavigationService._();

  static const _maxPackageName = '...'; // TODO: replace with actual MAX package name if known

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

  static Future<void> callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch phone dialer');
    }
  }

  static Future<void> openMessenger(
    BuildContext context, {
    required String phone,
    required String message,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: message));
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Текст заказа скопирован')),
      );
    } catch (_) {}

    final encoded = Uri.encodeComponent(message);
    final candidates = <Uri>[
      Uri.parse('max://chat?phone=$phone&text=$encoded'),
      Uri.parse('maxapp://chat?phone=$phone&text=$encoded'),
    ];

    if (_maxPackageName != '...') {
      candidates.add(
        Uri.parse(
          'intent://chat?phone=$phone&text=$encoded#Intent;package=$_maxPackageName;scheme=max;end',
        ),
      );
    }

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    try {
      final sms = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
      if (await canLaunchUrl(sms)) {
        await launchUrl(sms);
      }
    } catch (_) {}
  }
}
