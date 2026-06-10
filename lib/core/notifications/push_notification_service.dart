import 'dart:async';
import 'dart:ui';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/models/order_item.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _pendingPushOrderIdsKey = 'pending_push_order_ids_v1';
const _pendingPushRefreshKey = 'pending_push_refresh_v1';
const _debugPushLogs = bool.fromEnvironment('ORDER_DEBUG_LOGS');

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
  debugPrint('[PushService] $message');
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  if (!await _ensureFirebasePushInitialized(logErrors: false)) return;
  await _rememberBackgroundPush(message);
}

Future<bool> initializeFirebasePushBackgroundHandling() async {
  if (kIsWeb) return false;
  final initialized = await _ensureFirebasePushInitialized();
  if (!initialized) return false;

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  return true;
}

Future<bool> _ensureFirebasePushInitialized({bool logErrors = true}) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    return true;
  } catch (error) {
    if (logErrors) _logPushDebug('Firebase push disabled: $error');
    return false;
  }
}

String? _orderIdFromMessage(RemoteMessage message) {
  final orderId = message.data['order_id'] as String?;
  if (orderId == null || orderId.isEmpty) return null;
  return orderId;
}

Future<void> _rememberBackgroundPush(RemoteMessage message) async {
  final prefs = await SharedPreferences.getInstance();
  final orderId = _orderIdFromMessage(message);
  if (orderId == null) {
    if (message.data.isEmpty && message.notification != null) {
      await prefs.setBool(_pendingPushRefreshKey, true);
    }
    return;
  }

  final pendingOrderIds = prefs.getStringList(_pendingPushOrderIdsKey) ?? [];
  if (!pendingOrderIds.contains(orderId)) {
    pendingOrderIds.add(orderId);
    await prefs.setStringList(_pendingPushOrderIdsKey, pendingOrderIds);
  }
}

Future<_PendingBackgroundPushes> _takePendingBackgroundPushes() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final orderIds = prefs.getStringList(_pendingPushOrderIdsKey) ?? const [];
    final needsRefresh = prefs.getBool(_pendingPushRefreshKey) ?? false;
    await prefs.remove(_pendingPushOrderIdsKey);
    await prefs.remove(_pendingPushRefreshKey);
    return _PendingBackgroundPushes(
      orderIds: orderIds.toSet().toList(growable: false),
      needsRefresh: needsRefresh,
    );
  } catch (error) {
    _logPushDebug('Failed to drain background push queue: $error');
    return const _PendingBackgroundPushes();
  }
}

class _PendingBackgroundPushes {
  final List<String> orderIds;
  final bool needsRefresh;

  const _PendingBackgroundPushes({
    this.orderIds = const [],
    this.needsRefresh = false,
  });
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

    if (!await initializeFirebasePushBackgroundHandling()) return;

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

    await _emitPendingBackgroundPushes();

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage);
    }

    await _registerCurrentDevice(SupabaseBackend.currentSession);
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
    if (client == null || token.isEmpty) return;

    try {
      final session = await SupabaseBackend.refreshSessionIfNeeded();
      if (session == null) return;
      final user = session.user;

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
    final type = message.data['type'] as String?;
    final orderId = _orderIdFromMessage(message);

    if (_debugPushLogs) {
      _logPushDebug(
        'Message received type=${type ?? '-'} orderId=${orderId ?? '-'} '
        'dataKeys=${message.data.keys.join(',')} '
        'hasNotification=${message.notification != null}',
      );
    }

    if (type == 'new_order' && orderId != null && orderId.isNotEmpty) {
      unawaited(_emitOrder(orderId));
      return;
    }

    // On Android, notification messages received while the app is in the
    // background may arrive with an empty data map — the system shows the
    // notification but strips the data payload.  Trigger a full refresh so
    // the new order still appears when the user opens the app.
    if (type == null && message.data.isEmpty) {
      _events.add(NewOrderRefreshRequestedEvent(orderId: orderId ?? ''));
    }
  }

  Future<void> _emitPendingBackgroundPushes() async {
    final pending = await _takePendingBackgroundPushes();
    if (_debugPushLogs &&
        (pending.orderIds.isNotEmpty || pending.needsRefresh)) {
      _logPushDebug(
        'Drained background pushes ids=${pending.orderIds.length} '
        'needsRefresh=${pending.needsRefresh}',
      );
    }
    for (final orderId in pending.orderIds) {
      unawaited(_emitOrder(orderId));
    }
    if (pending.needsRefresh) {
      _events.add(const NewOrderRefreshRequestedEvent(orderId: ''));
    }
  }

  Future<void> _emitOrder(String orderId) async {
    for (final delay in _orderLoadRetryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final order = await _loadPushedOrder(orderId);
      if (order == null) continue;

      if (_debugPushLogs) {
        _logPushDebug('Loaded pushed order ${order.displayId}');
      }
      _events.add(NewOrderPushEvent(order: order));
      return;
    }

    if (_debugPushLogs) {
      _logPushDebug('Pushed order $orderId could not be loaded, refreshing');
    }
    _events.add(NewOrderRefreshRequestedEvent(orderId: orderId));
  }

  Future<OrderItem?> _loadPushedOrder(String orderId) async {
    final client = SupabaseBackend.client;
    if (client == null || SupabaseBackend.currentSession == null) return null;

    try {
      final session = await SupabaseBackend.refreshSessionIfNeeded();
      if (session == null) return null;
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
