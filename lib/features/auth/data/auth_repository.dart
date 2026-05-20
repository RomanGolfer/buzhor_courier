import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthResult {
  final bool isBackendSession;
  final String? errorMessage;

  const AuthResult._({required this.isBackendSession, this.errorMessage});

  const AuthResult.success({required bool isBackendSession})
    : this._(isBackendSession: isBackendSession);

  const AuthResult.failure(String message)
    : this._(isBackendSession: false, errorMessage: message);

  bool get isSuccess => errorMessage == null;
}

abstract class AuthRepository {
  bool get isBackendEnabled;
  Future<AuthResult> signIn({required String email, required String password});
}

class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository();

  @override
  bool get isBackendEnabled => false;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    return const AuthResult.success(isBackendSession: false);
  }
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isBackendEnabled => true;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return const AuthResult.failure('Введите email и пароль');
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      if (response.session == null) {
        return const AuthResult.failure('Не удалось открыть сессию');
      }
      return const AuthResult.success(isBackendSession: true);
    } on AuthException catch (error) {
      return AuthResult.failure(error.message);
    } catch (_) {
      return const AuthResult.failure('Не удалось подключиться к серверу');
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = SupabaseBackend.client;
  if (client == null) return const DemoAuthRepository();
  return SupabaseAuthRepository(client);
});
