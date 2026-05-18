import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/auth/screens/login_screen.dart';
import 'package:buzhor_courier/core/theme/app_theme.dart';
import 'package:buzhor_courier/core/theme/theme_mode_provider.dart';
import 'package:buzhor_courier/core/notifications/push_notification_listener.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const PushNotificationListener(child: LoginScreen()),
    );
  }
}
