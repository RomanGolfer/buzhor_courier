import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_worker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/auth/widgets/auth_gate.dart';
import 'package:buzhor_courier/core/theme/app_theme.dart';
import 'package:buzhor_courier/core/theme/theme_mode_provider.dart';
import 'package:buzhor_courier/core/notifications/push_notification_listener.dart';
import 'package:buzhor_courier/core/notifications/push_notification_service.dart';
import 'package:buzhor_courier/features/orders/realtime/realtime_order_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBackend.initialize();
  await initializeFirebasePushBackgroundHandling();
  OrderSyncWorker.instance.start();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: BuzhorApp()));
}

class BuzhorApp extends ConsumerWidget {
  const BuzhorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Бужор Доставка',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        return PushNotificationListener(
          child: RealtimeOrderListener(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const _StartupSplash(child: AuthGate()),
    );
  }
}

class _StartupSplash extends StatefulWidget {
  const _StartupSplash({required this.child});

  final Widget child;

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash> {
  static const _minimumDuration = Duration(milliseconds: 1200);

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_minimumDuration, () {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _ready ? widget.child : const _LaunchLogoScreen(),
    );
  }
}

class _LaunchLogoScreen extends StatelessWidget {
  const _LaunchLogoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/buzhor_logo_transparent.png',
          width: 240,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
