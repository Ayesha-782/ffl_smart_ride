import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/features/auth/widgets/auth_card.dart';
import 'package:ffl_smart_ride/features/auth/widgets/auth_header.dart';
import 'package:ffl_smart_ride/features/auth/widgets/auth_primary_button.dart';
import 'package:ffl_smart_ride/features/auth/widgets/auth_text_field.dart';
import 'package:ffl_smart_ride/features/auth/screens/login_screen.dart';
import 'package:ffl_smart_ride/features/registration/screens/registration_screen.dart';

void main() {
  group('Auth UI & Design System Component Tests', () {
    testWidgets('AuthCard enforces maxWidth constraint on wide viewports', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthCard(
              maxWidth: 460,
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(AuthCard);
      expect(cardFinder, findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);

      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 460,
      );
      expect(constrainedBoxFinder, findsOneWidget);
    });

    testWidgets('AuthHeader renders brand icon, badge, title and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthHeader(
              title: 'Welcome Back 👋',
              subtitle: 'Sign in to access your portal',
              badgeText: 'FFL SMART RIDE',
            ),
          ),
        ),
      );

      expect(find.text('Welcome Back 👋'), findsOneWidget);
      expect(find.text('Sign in to access your portal'), findsOneWidget);
      expect(find.text('FFL SMART RIDE'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
    });

    testWidgets('AuthPrimaryButton renders text, icon, and switches to spinner on loading', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthPrimaryButton(
              text: 'Sign In',
              icon: Icons.login,
              isLoading: false,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);

      await tester.tap(find.text('Sign In'));
      await tester.pump();
      expect(tapped, isTrue);

      // Pump in loading state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthPrimaryButton(
              text: 'Sign In',
              isLoading: true,
              onPressed: () => tapped = false,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AuthTextField shows label, hint, and error when invalid', (tester) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AuthTextField(
                controller: controller,
                label: 'Work Email',
                hint: 'user@ffl.com',
                prefixIcon: Icons.email_outlined,
                validator: (val) => val == null || val.isEmpty ? 'Email is required' : null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Work Email'), findsOneWidget);
      expect(find.text('user@ffl.com'), findsOneWidget);

      // Trigger form validation
      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('LoginScreen renders all input fields and password toggle works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Welcome Back 👋'), findsOneWidget);
      expect(find.text('Work Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.textContaining('Create Account'), findsOneWidget);

      // Password toggle button
      final toggleFinder = find.byTooltip('Show password');
      expect(toggleFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pump();
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('RegistrationScreen renders all form sections and vehicle switch works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      expect(find.text('Create Employee Account'), findsOneWidget);
      expect(find.text('Employee Details'), findsOneWidget);
      expect(find.text('Account Security'), findsOneWidget);
      expect(find.text('Home Address'), findsWidgets);

      // Scroll to Vehicle section
      final switchFinder = find.byType(Switch);
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Information (Optional)'), findsOneWidget);
      expect(switchFinder, findsOneWidget);

      // Toggle switch off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // After toggle off, non-driver passenger message is shown
      expect(
        find.text('You are registering as a Passenger only. You can add a vehicle later.'),
        findsOneWidget,
      );
    });
  });
}
