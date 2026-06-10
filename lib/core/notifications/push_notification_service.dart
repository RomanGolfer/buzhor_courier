import 'dart:async';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

sealed class PushNotificationEvent {
  const PushNotificationEvent();
}

class NewOrderPushEvent extends PushNotificationEvent {
  final OrderItem order;

  const NewOrderPushEvent({required this.order});
}

class NewOrderRefreshRequestedEvent extends PushNotificationEvent {
  final String orderId;

  const NewOrderRefreshRequestedEvent({required this.orderId});
}

abstract class PushNotificationService {
  Stream<PushNotificationEvent> get events;
  Future<void> initialize();
}

class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Stream<PushNotificationEvent> get events => const Stream.empty();

  @override
  Future<void> initialize() async {}
}

void _logPushDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class FirebasePushNotificationService implements PushNotificationService {
  static const _orderLoadRetryDelays = [
    Duration.zero,
    Duration(milliseconds: 600),
    Duration(seconds: 2),
    Duration(seconds: 5),
  ];

  final _events = StreamController<PushNotificationEvent>.broadcast();

  bool _initialized = false;

  @override
  Stream<PushNotificationEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final client = SupabaseBackend.client;
    if (client == null || kIsWeb) return;

    try {
      await Firebase.initializeApp();
    } catch (error) {
      _logPushDebug('Firebase push disabled: $error');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    client.auth.onAuthStateChange.listen((data) {
      unawaited(_registerCurrentDevice(data.session));
    });
    messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });
    FirebaseMessaging.onMessage.listen(_handleRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage);
    }

    await _registerCurrentDevice(client.auth.currentSession);
  }

  Future<void> _registerCurrentDevice(Session? session) async {
    if (session == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (error) {
      _logPushDebug('Failed to read FCM token: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    final client = SupabaseBackend.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null || token.isEmpty) return;

    try {
      final courierId = await _currentCourierId(client, user.id);
      await client.from('device_push_tokens').upsert({
        'profile_id': user.id,
        'courier_id': courierId,
        'fcm_token': token,
        'platform': _platformName(),
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
    } catch (error) {
      _logPushDebug('Failed to register FCM token: $error');
    }
  }

  Future<String?> _currentCourierId(
    SupabaseClient client,
    String userId,
  ) async {
    final row = await client
        .from('couriers')
        .select('id')
        .eq('profile_id', userId)
        .eq('is_active', true)
        .maybeSingle();
    return row?['id'] as String?;
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final type = message.data['type'];
    final orderId = message.data['order_id'];
    if (type != 'new_order' || orderId == null || orderId.isEmpty) return;
    unawaited(_emitOrder(orderId));
  }

  Future<void> _emitOrder(String orderId) async {
    for (final delay in _orderLoadRetryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final order = await _loadPushedOrder(orderId);
      if (order == null) continue;

      _events.add(NewOrderPushEvent(order: order));
      return;
    }

    _events.add(NewOrderRefreshRequestedEvent(orderId: orderId));
  }

  Future<OrderItem?> _loadPushedOrder(String orderId) async {
    final client = SupabaseBackend.client;
    final session = client?.auth.currentSession;
    if (client == null || session == null) return null;

    try {
      if (session.isExpired) {
        await client.auth.refreshSession();
      }

      final row = await client
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();
      if (row == null) return null;

      return OrderItem.fromBackendJson(row);
    } catch (error) {
      _logPushDebug('Failed to load pushed order $orderId: $error');
      return null;
    }
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => FirebasePushNotificationService(),
);
