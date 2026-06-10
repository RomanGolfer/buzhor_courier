import 'dart:async';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:flutter/foundation.dart';
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

enum CourierAppAccessStatus { allowed, denied, unavailable }

const courierAppAccessDeniedMessage = 'Нет доступа к приложению курьера';
const courierAppAccessUnavailableMessage = 'Не удалось проверить доступ';
const courierAppAccessCheckTimeout = Duration(seconds: 12);

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

class DisabledBackendAuthRepository implements AuthRepository {
  const DisabledBackendAuthRepository();

  @override
  bool get isBackendEnabled => false;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return const AuthResult.failure(
      'Приложение собрано без подключения к серверу. Обратитесь к администратору.',
    );
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
      final accessStatus = await checkCourierAppAccess(
        _client,
        response.session!.user.id,
      );
      if (accessStatus != CourierAppAccessStatus.allowed) {
        await signOutSilently(_client);
        return AuthResult.failure(courierAccessFailureMessage(accessStatus));
      }
      return const AuthResult.success(isBackendSession: true);
    } on AuthException catch (error) {
      return AuthResult.failure(authExceptionFailureMessage(error));
    } catch (_) {
      await signOutSilently(_client);
      return const AuthResult.failure('Не удалось подключиться к серверу');
    }
  }
}

Future<CourierAppAccessStatus> checkCourierAppAccess(
  SupabaseClient client,
  String userId,
) async {
  try {
    await SupabaseBackend.refreshSessionIfNeeded();
    return await _loadCourierAppAccess(
      client,
      userId,
    ).timeout(courierAppAccessCheckTimeout);
  } catch (_) {
    return CourierAppAccessStatus.unavailable;
  }
}

Future<CourierAppAccessStatus> _loadCourierAppAccess(
  SupabaseClient client,
  String userId,
) async {
  final profile = await client
      .from('profiles')
      .select('role, is_active')
      .eq('id', userId)
      .maybeSingle();

  if (!courierProfileCanUseApp(profile)) {
    return CourierAppAccessStatus.denied;
  }

  final courier = await client
      .from('couriers')
      .select('id, is_active')
      .eq('profile_id', userId)
      .eq('is_active', true)
      .maybeSingle();

  return courier == null
      ? CourierAppAccessStatus.denied
      : CourierAppAccessStatus.allowed;
}

Future<void> signOutSilently(SupabaseClient client) async {
  try {
    await client.auth.signOut();
  } catch (_) {}
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = SupabaseBackend.client;
  if (client == null) {
    if (kReleaseMode) return const DisabledBackendAuthRepository();
    return const DemoAuthRepository();
  }
  return SupabaseAuthRepository(client);
});

@visibleForTesting
String authExceptionFailureMessage(AuthException _) {
  return 'Неверный email или пароль';
}

@visibleForTesting
bool courierProfileCanUseApp(Map<String, dynamic>? profile) {
  return profile?['is_active'] == true && profile?['role'] == 'courier';
}

@visibleForTesting
String courierAccessFailureMessage(CourierAppAccessStatus status) {
  return switch (status) {
    CourierAppAccessStatus.allowed => '',
    CourierAppAccessStatus.denied => courierAppAccessDeniedMessage,
    CourierAppAccessStatus.unavailable => courierAppAccessUnavailableMessage,
  };
}
