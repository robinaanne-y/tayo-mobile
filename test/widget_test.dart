import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayo/main.dart';

void main() {
  setUp(() {
    // flutter_secure_storage talks to native platform code over a method
    // channel that isn't available in widget tests; stub it so
    // SecureTokenStorage.readToken() resolves to "no token" instead of
    // throwing MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  testWidgets('unauthenticated user lands on the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TayoApp()));

    // First frame is the splash screen while auth status is unknown.
    expect(find.text('Tayo'), findsOneWidget);

    await tester.pumpAndSettle();

    // No stored token -> router redirects to /login.
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
