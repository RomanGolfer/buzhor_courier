import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackend {
  static const sessionRefreshMargin = Duration(minutes: 2);
  static const defaultProjectUrl = 'https://txzzkrqekynqansqvnbj.supabase.co';
  static const _projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultProjectUrl,
  );
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _isInitialized = false;
  static StreamSubscription<AuthState>? _authStateSubscription;

  static String get projectUrl => _projectUrl;
  static String get clientKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey;
  static bool get isConfigured => clientKey.isNotEmpty;
  static bool get isInitialized => _isInitialized;
  static SupabaseClient? get client =>
      _isInitialized ? Supabase.instance.client : null;
  static Session? get currentSession {
    final client = SupabaseBackend.client;
    if (client == null) return null;

    final session = client.auth.currentSession;
    _applyRestAuth(client, session);
    return session;
  }

  static Future<void> initialize() async {
    if (!isConfigured || _isInitialized) return;

    await Supabase.initialize(
      url: projectUrl,
      publishableKey: clientKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    _bindRestAuth(Supabase.instance.client);
    _isInitialized = true;
  }

  static Future<Session?> refreshSessionIfNeeded({
    Duration margin = sessionRefreshMargin,
  }) async {
    final client = SupabaseBackend.client;
    final session = client?.auth.currentSession;
    if (client == null) return null;
    if (session == null) {
      _applyRestAuth(client, null);
      return null;
    }

    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      _applyRestAuth(client, session);
      return session;
    }

    final expiresAtTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final shouldRefresh = DateTime.now().add(margin).isAfter(expiresAtTime);
    if (!shouldRefresh) {
      _applyRestAuth(client, session);
      return session;
    }

    await client.auth.refreshSession();
    final refreshedSession = client.auth.currentSession;
    _applyRestAuth(client, refreshedSession);
    return refreshedSession;
  }

  static void _bindRestAuth(SupabaseClient client) {
    _authStateSubscription?.cancel();
    _applyRestAuth(client, client.auth.currentSession);
    _authStateSubscription = client.auth.onAuthStateChange.listen((event) {
      _applyRestAuth(client, event.session);
    });
  }

  static void _applyRestAuth(SupabaseClient client, Session? session) {
    client.rest.setAuth(session?.accessToken);
  }
}
