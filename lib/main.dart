import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buzhor_courier/features/auth/screens/login_screen.dart';
import 'package:buzhor_courier/theme/app_theme.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: BuzhorApp()));
}

class BuzhorApp extends StatelessWidget {
  const BuzhorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Бужор Доставка',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const LoginScreen(),
    );
  }
}
