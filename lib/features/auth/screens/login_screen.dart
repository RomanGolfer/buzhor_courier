import 'dart:math' as math;

import 'package:buzhor_courier/shared/models/bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/auth/widgets/bubble_painter.dart';
import 'package:buzhor_courier/features/auth/providers/login_provider.dart';
import 'package:buzhor_courier/features/orders/screens/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sheetController = DraggableScrollableController();

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

    _sheetController.addListener(() {
      final expanded = _sheetController.size > 0.6;
      if (expanded != ref.read(loginStateProvider).isExpanded) {
        ref.read(loginStateProvider.notifier).setExpanded(expanded);
      }
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
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginStateProvider);
    final overlayStyle = state.isExpanded
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF071E3D),
                  Color(0xFF0D3D6E),
                  Color(0xFF1565A8),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: CustomPaint(
              painter: BubblePainter(_bubbles),
              child: Container(),
            ),
          ),
          SafeArea(
            child: AnimatedOpacity(
              opacity: state.isExpanded ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/buzhor_logo_transparent.png',
                          width: 240,
                          height: 130,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 1,
                              color: const Color(
                                0xFF5BB8F5,
                              ).withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'КУРЬЕРСКОЕ ПРИЛОЖЕНИЕ',
                              style: TextStyle(
                                color: Color(0xFF5BB8F5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 30,
                              height: 1,
                              color: const Color(
                                0xFF5BB8F5,
                              ).withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.50,
            minChildSize: 0.50,
            maxChildSize: 1.0,
            snap: true,
            snapSizes: const [0.50, 1.0],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 8,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      28,
                      16,
                      28,
                      MediaQuery.of(context).viewInsets.bottom +
                          MediaQuery.of(context).padding.bottom +
                          100,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD6E4F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 28),
                        AnimatedOpacity(
                          opacity: state.isExpanded ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: state.isExpanded
                              ? Column(
                                  children: [
                                    Image.asset(
                                      'assets/buzhor_logo_transparent.png',
                                      width: 180,
                                      height: 90,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Добро пожаловать',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D3D6E),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Войдите в аккаунт курьера',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B8CAE),
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
                            color: const Color(
                              0xFF6B8CAE,
                            ).withValues(alpha: 0.6),
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool focused,
    required Function(bool) onFocus,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Focus(
      onFocusChange: onFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: focused ? const Color(0xFFE8F1FB) : const Color(0xFFF0F5FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? const Color(0xFF1B5FA8) : const Color(0xFFE0EDF8),
            width: focused ? 2 : 1.5,
          ),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Color(0xFF0D3D6E),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF6B8CAE).withValues(alpha: 0.5),
            ),
            labelStyle: TextStyle(
              color: focused
                  ? const Color(0xFF1B5FA8)
                  : const Color(0xFF6B8CAE),
              fontWeight: focused ? FontWeight.w600 : FontWeight.normal,
            ),
            prefixIcon: Icon(
              icon,
              color: focused
                  ? const Color(0xFF1B5FA8)
                  : const Color(0xFF6B8CAE),
              size: 20,
            ),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffix,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}
