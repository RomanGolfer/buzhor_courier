import 'package:buzhor_courier/core/backend/supabase_backend.dart';
import 'package:buzhor_courier/features/orders/data/order_sync_worker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/auth/screens/login_screen.dart';
import 'package:buzhor_courier/core/theme/app_theme.dart';
import 'package:buzhor_courier/core/theme/theme_mode_provider.dart';
import 'package:buzhor_courier/core/notifications/push_notification_listener.dart';
import 'package:buzhor_courier/features/orders/realtime/realtime_order_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBackend.initialize();
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
      home: const PushNotificationListener(
        child: RealtimeOrderListener(
          child: LoginScreen(),
        ),
      ),
    );
  }
}