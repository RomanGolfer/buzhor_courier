import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'screens/home_screen.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BuzhorApp());
}

class BuzhorApp extends StatelessWidget {
  const BuzhorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Бужор Доставка',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

class Bubble {
  double x, y, size, speed, opacity;
  Bubble(this.x, this.y, this.size, this.speed, this.opacity);
}

class BubblePainter extends CustomPainter {
  final List<Bubble> bubbles;
  BubblePainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final paint = Paint()
        ..color = const Color(0xFF5BB8F5).withValues(alpha: b.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset(b.x * size.width, b.y * size.height), b.size, paint);
      final innerPaint = Paint()
        ..color = const Color(0xFF5BB8F5).withValues(alpha: b.opacity * 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(b.x * size.width, b.y * size.height), b.size, innerPaint);
    }
  }

  @override
  bool shouldRepaint(BubblePainter old) => true;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sheetController = DraggableScrollableController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _phoneFocused = false;
  bool _passFocused = false;
  bool _isExpanded = false;

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
      _bubbles.add(Bubble(
        _random.nextDouble(),
        _random.nextDouble(),
        _random.nextDouble() * 18 + 4,
        _random.nextDouble() * 0.003 + 0.001,
        _random.nextDouble() * 0.12 + 0.04,
      ));
    }

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _bubbleController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack));

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
      if (expanded != _isExpanded) {
        setState(() => _isExpanded = expanded);
      }
    });

    Future.delayed(const Duration(milliseconds: 100), () => _logoController.forward());
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Фон с градиентом и пузырьками
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF071E3D), Color(0xFF0D3D6E), Color(0xFF1565A8)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: CustomPaint(
              painter: BubblePainter(_bubbles),
              child: Container(),
            ),
          ),

          // Логотип — скрывается когда карточка раскрыта
          SafeArea(
            child: AnimatedOpacity(
              opacity: _isExpanded ? 0.0 : 1.0,
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
                            Container(width: 30, height: 1, color: const Color(0xFF5BB8F5).withValues(alpha: 128)),
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
                            Container(width: 30, height: 1, color: const Color(0xFF5BB8F5).withValues(alpha: 128)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Draggable bottom sheet
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
                      blurRadius: 30,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      28, 16, 28,
                      MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 100,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Рычажок
                        Container(
                          width: 36, height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD6E4F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Логотип внутри карточки когда раскрыта
                        AnimatedOpacity(
                          opacity: _isExpanded ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: _isExpanded ? Column(
                            children: [
                              Image.asset(
                                'assets/buzhor_logo_transparent.png',
                                width: 180,
                                height: 90,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ) : const SizedBox.shrink(),
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
                          focused: _phoneFocused,
                          onFocus: (v) => setState(() => _phoneFocused = v),
                        ),
                        const SizedBox(height: 16),

                        _buildField(
                          controller: _passwordController,
                          label: 'Пароль',
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePassword,
                          focused: _passFocused,
                          onFocus: (v) => setState(() => _passFocused = v),
                          suffix: GestureDetector(
                            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                            child: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: const Color(0xFF6B8CAE),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Оранжевая кнопка
                        GestureDetector(
                          onTap: _isLoading ? null : () async {
                            setState(() => _isLoading = true);
                            final nav = Navigator.of(context);
                            await Future.delayed(const Duration(milliseconds: 1500));
                            if (!mounted) return;
                            nav.pushReplacement(
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
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
                                  color: const Color(0xFFE8720C).withValues(alpha: 115),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5,
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
                            color: const Color(0xFF6B8CAE).withValues(alpha: 153),
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
            hintStyle: TextStyle(color: const Color(0xFF6B8CAE).withValues(alpha: 128)),
            labelStyle: TextStyle(
              color: focused ? const Color(0xFF1B5FA8) : const Color(0xFF6B8CAE),
              fontWeight: focused ? FontWeight.w600 : FontWeight.normal,
            ),
            prefixIcon: Icon(icon,
              color: focused ? const Color(0xFF1B5FA8) : const Color(0xFF6B8CAE),
              size: 20,
            ),
            suffixIcon: suffix != null ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffix,
            ) : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }
}