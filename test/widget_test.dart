import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Verify Login Screen headers and inputs
    expect(find.text('Welcome Back 👋'), findsOneWidget);
    expect(find.text('Work Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });
}
