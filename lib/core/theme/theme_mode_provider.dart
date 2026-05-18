import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadSavedMode();
  }

  static const _themeModeKey = 'theme_mode_v1';

  Future<void> _loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);
    if (savedMode == ThemeMode.dark.name) {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = nextMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, nextMode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
