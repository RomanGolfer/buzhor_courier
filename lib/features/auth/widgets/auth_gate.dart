import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/auth/screens/login_screen.dart';
import 'package:buzhor_courier/features/orders/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = SupabaseBackend.client;
    if (client == null) return const LoginScreen();

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData
            ? snapshot.data!.session
            : client.auth.currentSession;
        return session != null ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
