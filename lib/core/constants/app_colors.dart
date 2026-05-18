import 'package:flutter/material.dart';

class AppColors {
  static const blue = Color(0xFF1B5FA8);
  static const darkBlue = Color(0xFF0D3D6E);
  static const lightBlue = Color(0xFF5BB8F5);
  static const green = Color(0xFF4A8C2A);
  static const orange = Color(0xFFE8720C);
  static const orangeLight = Color(0xFFFF9A3C);
  static const bg = Color(0xFFF0F5FB);
  static const liveGreen = Color(0xFF6FCF3A);
  static const purple = Color(0xFF7B3FE4);
  static const grayBlue = Color(0xFF6B8CAE);
  static const grayBlueLight = Color(0xFF8AACCC);
  static const cardBg = Color(0xFFEEF4FB);
  static const divider = Color(0xFFD6E4F0);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color softSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF172B40) : cardBg;

  static Color dividerColor(BuildContext context) =>
      Theme.of(context).dividerColor;
}
