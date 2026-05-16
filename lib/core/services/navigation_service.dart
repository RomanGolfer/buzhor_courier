import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  NavigationService._();

  static const _missingPhoneMessage = 'Нет номера телефона';
  static const _callErrorMessage = 'Не удалось открыть звонок';
  static const _smsErrorMessage = 'Не удалось открыть SMS';

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

  static Future<bool> callPhone(String? phone) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone == null) return false;

    try {
      return launchUrl(
        Uri(scheme: 'tel', path: normalizedPhone),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sendSms({
    required String? phone,
    required String message,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone == null) return false;

    try {
      return launchUrl(
        Uri(
          scheme: 'sms',
          path: normalizedPhone,
          queryParameters: {'body': message},
        ),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> callPhoneWithFeedback(
    BuildContext context, {
    required String? phone,
  }) async {
    final success = await callPhone(phone);
    if (success || !context.mounted) return;
    _showSnackBar(
      context,
      _normalizePhone(phone) == null ? _missingPhoneMessage : _callErrorMessage,
    );
  }

  static Future<void> sendSmsWithFeedback(
    BuildContext context, {
    required String? phone,
    required String message,
  }) async {
    final success = await sendSms(phone: phone, message: message);
    if (success || !context.mounted) return;
    _showSnackBar(
      context,
      _normalizePhone(phone) == null ? _missingPhoneMessage : _smsErrorMessage,
    );
  }

  static Future<bool> openMessenger(
    BuildContext context, {
    required String? phone,
    required String message,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone == null) {
      _showSnackBar(context, _missingPhoneMessage);
      return false;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: message));
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Текст заказа скопирован')),
      );
    } catch (_) {}

    final encoded = Uri.encodeComponent(message);
    final candidates = <Uri>[
      Uri.parse('max://chat?phone=$normalizedPhone&text=$encoded'),
      Uri.parse('maxapp://chat?phone=$normalizedPhone&text=$encoded'),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
    }

    final smsOpened = await sendSms(phone: normalizedPhone, message: message);
    if (!smsOpened && context.mounted) {
      _showSnackBar(context, _smsErrorMessage);
    }
    return smsOpened;
  }

  static String? _normalizePhone(String? phone) {
    final trimmed = phone?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceAll(RegExp(r'[\s()-]'), '');
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
