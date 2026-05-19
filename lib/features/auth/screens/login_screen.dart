import 'dart:math' as math;

import 'package:buzhor_courier/shared/models/bubble.dart';
import 'package:buzhor_courier/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/auth/widgets/bubble_painter.dart';
import 'package:buzhor_courier/features/auth/providers/login_provider.dart';
import 'package:buzhor_courier/features/orders/screens/home_screen.dart';

part 'login_background.dart';
part 'login_form_field.dart';
part 'login_logo_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
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
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            _buildAnimatedBackground(),

            _buildLogoHeader(),

            // Fixed white card in bottom 55%
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E2E)
                      : Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 8,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom +
                      24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добро пожаловать',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : AppColors.darkBlue,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Войдите в аккаунт курьера',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white60
                                  : AppColors.grayBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildField(
                      controller: _phoneController,
                      label: 'Номер телефона',
                      hint: '+7 900 000 00 00',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      focused: state.phoneFocused,
                      onFocus: (v) => ref
                          .read(loginStateProvider.notifier)
                          .setPhoneFocused(v),
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _passwordController,
                      label: 'Пароль',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: state.obscurePassword,
                      focused: state.passFocused,
                      onFocus: (v) => ref
                          .read(loginStateProvider.notifier)
                          .setPassFocused(v),
                      suffix: GestureDetector(
                        onTap: ref
                            .read(loginStateProvider.notifier)
                            .toggleObscurePassword,
                        child: Icon(
                          state.obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF6B8CAE),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: state.isLoading
                          ? null
                          : () async {
                              ref
                                  .read(loginStateProvider.notifier)
                                  .setLoading(true);
                              final nav = Navigator.of(context);
                              await Future.delayed(
                                const Duration(milliseconds: 1500),
                              );
                              if (!mounted) return;
                              nav.pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                              );
                            },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE8720C), Color(0xFFFF9A3C)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFE8720C,
                              ).withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: state.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Войти',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Бужор · Анапа',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.38)
                            : const Color(0xFF6B8CAE).withValues(alpha: 0.6),
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
