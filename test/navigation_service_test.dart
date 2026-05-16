import 'package:buzhor_courier/core/services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _testPhone = '+79385358777';
const _testMessage = 'Заказ 123';

String? _extractUrl(dynamic args) {
  if (args is String) return args;
  if (args is Map) {
    return args['url'] as String? ?? args['uri'] as String?;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel urlLauncherChannel;
  late List<String> canLaunchCalls;
  late List<String> launchCalls;
  late List<String> clipboardValues;

  setUp(() {
    urlLauncherChannel = const MethodChannel('plugins.flutter.io/url_launcher');
    canLaunchCalls = <String>[];
    launchCalls = <String>[];
    clipboardValues = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
          final url = _extractUrl(call.arguments);
          if (call.method == 'canLaunch' || call.method == 'canLaunchUrl') {
            if (url != null) canLaunchCalls.add(url);
            return true;
          }

          if (call.method == 'launch' || call.method == 'launchUrl') {
            if (url != null) launchCalls.add(url);
            return true;
          }

          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = call.arguments as Map<dynamic, dynamic>?;
            final text = data?['text'] as String?;
            if (text != null) {
              clipboardValues.add(text);
            }
            return null;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('copies text and opens MAX deep link when available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                NavigationService.openMessenger(
                  context,
                  phone: _testPhone,
                  message: _testMessage,
                );
              },
              child: const Text('Open Messenger'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Messenger'));
    await tester.pumpAndSettle();

    expect(clipboardValues, [_testMessage]);
    expect(find.text('Текст заказа скопирован'), findsOneWidget);
    expect(canLaunchCalls, isNotEmpty);
    expect(
      launchCalls.any(
        (url) => url.startsWith('max://') || url.startsWith('maxapp://'),
      ),
      isTrue,
    );
  });

  testWidgets('falls back to SMS when MAX deep link cannot be opened', (
    WidgetTester tester,
  ) async {
    late List<String> outgoingUrls;
    outgoingUrls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
          final url = _extractUrl(call.arguments);
          if (call.method == 'canLaunch' || call.method == 'canLaunchUrl') {
            if (url != null) {
              canLaunchCalls.add(url);
              final isSms = url.startsWith('sms:');
              return isSms;
            }
            return false;
          }
          if (call.method == 'launch' || call.method == 'launchUrl') {
            if (url != null) outgoingUrls.add(url);
            return true;
          }
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                NavigationService.openMessenger(
                  context,
                  phone: _testPhone,
                  message: _testMessage,
                );
              },
              child: const Text('Open Messenger'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Messenger'));
    await tester.pumpAndSettle();

    expect(clipboardValues, [_testMessage]);
    expect(find.text('Текст заказа скопирован'), findsOneWidget);
    expect(outgoingUrls.any((url) => url.startsWith('sms:')), isTrue);
  });
}
