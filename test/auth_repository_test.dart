import 'package:buzhor_courier/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('auth exception message is not exposed to the UI', () {
    final message = authExceptionFailureMessage(
      const AuthException(
        'technical backend auth details',
        statusCode: '400',
        code: 'invalid_credentials',
      ),
    );

    expect(message, 'Неверный email или пароль');
    expect(message, isNot(contains('technical backend auth details')));
  });

  test('disabled backend auth fails closed', () async {
    final result = await const DisabledBackendAuthRepository().signIn(
      email: 'courier@example.com',
      password: 'password',
    );

    expect(result.isSuccess, isFalse);
    expect(result.isBackendSession, isFalse);
  });
}
