import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayo/features/auth/presentation/screens/login_screen.dart';

void main() {
  Future<void> pumpSignup(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.tap(find.text('Sign up'));
    await tester.pump();
  }

  testWidgets('requires a name, email and 8+ character password', (tester) async {
    await pumpSignup(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('rejects a mismatched password confirmation', (tester) async {
    await pumpSignup(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Anna Santos');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'), 'anna@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'somethingelse',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
