import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayo/core/theme/app_theme.dart';
import 'package:tayo/features/auth/presentation/screens/login_screen.dart';
import 'package:tayo/shared/widgets/app_text_field.dart';

void main() {
  // Labels render above the input, so find the field via its AppTextField.
  Finder field(String label) => find.descendant(
        of: find.widgetWithText(AppTextField, label),
        matching: find.byType(TextFormField),
      );

  Future<void> pumpSignup(WidgetTester tester) async {
    // Phone-sized surface: the sign-up form is taller than the default
    // 800x600 test view, which would leave the submit button unbuilt.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
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

    await tester.enterText(field('Your name'), 'Anna Santos');
    await tester.enterText(field('Email address'), 'anna@example.com');
    await tester.enterText(field('Password'), 'password123');
    await tester.enterText(field('Confirm password'), 'somethingelse');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
