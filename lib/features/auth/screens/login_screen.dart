import 'dart:math' as math;

import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/core/config/backend_app_config.dart';
import 'package:buzhor_courier/features/auth/data/auth_credentials_storage.dart';
import 'package:buzhor_courier/features/auth/data/auth_repository.dart';
import 'package:buzhor_courier/shared/models/bubble.dart';
import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/auth/widgets/bubble_painter.dart';
import 'package:buzhor_courier/features/auth/providers/login_provider.dart';
import 'package:buzhor_courier/features/orders/screens/home_screen.dart';

part 'login_background.dart';
part 'login_form_card.dart';
part 'login_form_field.dart';
part 'login_logo_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _logoController;
  late AnimationController _bubbleController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;

  final List<Bubble> _bubbles = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    Future.microtask(_tryAutoLogin);

    for (int i = 0; i < 18; i++) {
      _bubbles.add(
        Bubble(
          _random.nextDouble(),
          _random.nextDouble(),
          _random.nextDouble() * 18 + 4,
          _random.nextDouble() * 0.003 + 0.001,
          _random.nextDouble() * 0.12 + 0.04,
        ),
      );
    }

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _bubbleController.addListener(() {
      setState(() {
        for (final b in _bubbles) {
          b.y -= b.speed;
          if (b.y < -0.05) {
            b.y = 1.05;
            b.x = _random.nextDouble();
          }
        }
      });
    });

    Future.delayed(
      const Duration(milliseconds: 100),
      () => _logoController.forward(),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _bubbleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final client = SupabaseBackend.client;
    if (client != null && client.auth.currentSession != null) {
      if (mounted) _navigateToHome();
      return;
    }

    final savedEmail = await ref
        .read(authCredentialsStorageProvider)
        .loadEmail();
    if (savedEmail != null && mounted) {
      _emailController.text = savedEmail;
    }
  }

  void _navigateToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginStateProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildAnimatedBackground(),
            _buildLogoHeader(),
            _buildLoginCard(state),
          ],
        ),
      ),
    );
  }
}
