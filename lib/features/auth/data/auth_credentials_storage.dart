import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthCredentialsStorage {
  static const _emailKey = 'auth_email';

  final _storage = const FlutterSecureStorage();

  Future<String?> loadEmail() async {
    return _storage.read(key: _emailKey);
  }

  Future<void> saveEmail(String email) async {
    await _storage.write(key: _emailKey, value: email);
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
  }
}

final authCredentialsStorageProvider = Provider<AuthCredentialsStorage>(
  (_) => AuthCredentialsStorage(),
);
