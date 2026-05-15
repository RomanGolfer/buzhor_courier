import 'package:buzhor_courier/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BuzhorApp()));
    // Drain the 100 ms Future.delayed that starts the logo animation.
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Добро пожаловать'), findsOneWidget);
  });
}
