import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackend {
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

  static String get projectUrl => _projectUrl;
  static String get clientKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey;
  static bool get isConfigured => clientKey.isNotEmpty;
  static bool get isInitialized => _isInitialized;
  static SupabaseClient? get client =>
      _isInitialized ? Supabase.instance.client : null;

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
    _isInitialized = true;
  }
}
