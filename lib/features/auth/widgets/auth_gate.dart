import 'dart:async';

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/auth/data/auth_repository.dart';
import 'package:buzhor_courier/features/auth/screens/login_screen.dart';
import 'package:buzhor_courier/features/orders/screens/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode && !SupabaseBackend.isConfigured) {
      return const _BackendConfigurationErrorScreen();
    }

    final client = SupabaseBackend.client;
    if (client == null) return const LoginScreen();

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? SupabaseBackend.currentSession;
        return session != null
            ? _CourierAccessGate(client: client, session: session)
            : const LoginScreen();
      },
    );
  }
}

class _CourierAccessGate extends StatefulWidget {
  const _CourierAccessGate({required this.client, required this.session});

  final SupabaseClient client;
  final Session session;

  @override
  State<_CourierAccessGate> createState() => _CourierAccessGateState();
}

class _CourierAccessGateState extends State<_CourierAccessGate> {
  late Future<CourierAppAccessStatus> _accessFuture;

  @override
  void initState() {
    super.initState();
    _loadAccessStatus();
  }

  @override
  void didUpdateWidget(covariant _CourierAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.user.id != widget.session.user.id) {
      _loadAccessStatus();
    }
  }

  void _loadAccessStatus() {
    _accessFuture = checkCourierAppAccess(
      widget.client,
      widget.session.user.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CourierAppAccessStatus>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _AccessCheckLoadingScreen();
        }

        switch (snapshot.data!) {
          case CourierAppAccessStatus.allowed:
            return const HomeScreen();
          case CourierAppAccessStatus.denied:
            return _AccessDeniedScreen(
              onSignOut: () => unawaited(signOutSilently(widget.client)),
            );
          case CourierAppAccessStatus.unavailable:
            return _AccessCheckErrorScreen(
              onRetry: () {
                setState(_loadAccessStatus);
              },
            );
        }
      },
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'У этого аккаунта нет доступа к приложению курьера. Проверьте, что профиль активен и привязан к активному курьеру.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onSignOut, child: const Text('Выйти')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessCheckLoadingScreen extends StatelessWidget {
  const _AccessCheckLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _AccessCheckErrorScreen extends StatelessWidget {
  const _AccessCheckErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Не удалось проверить доступ к приложению курьера. Проверьте интернет и попробуйте снова.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackendConfigurationErrorScreen extends StatelessWidget {
  const _BackendConfigurationErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Приложение собрано без подключения к серверу. Обратитесь к администратору.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
