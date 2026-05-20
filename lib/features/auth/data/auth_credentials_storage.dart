import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthCredentials {
  final String email;
  final String password;

  const AuthCredentials({required this.email, required this.password});
}

class AuthCredentialsStorage {
  static const _emailKey = 'auth_email';
  static const _passwordKey = 'auth_password';

  final _storage = const FlutterSecureStorage();

  Future<AuthCredentials?> load() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return null;
    return AuthCredentials(email: email, password: password);
  }

  Future<void> save({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

final authCredentialsStorageProvider = Provider<AuthCredentialsStorage>(
  (_) => AuthCredentialsStorage(),
);
