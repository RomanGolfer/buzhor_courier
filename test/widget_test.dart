import 'package:buzhor_courier/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BuzhorApp()));
    // Drain the startup splash and the 100 ms delayed login logo animation.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Добро пожаловать'), findsOneWidget);
  });

  testWidgets('App configures light and dark themes', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BuzhorApp()));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 200));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    expect(app.themeMode, ThemeMode.light);
  });
}
