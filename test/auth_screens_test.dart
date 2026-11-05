import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/auth/auth_screens.dart';

void main() {
  Widget testWrapper(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF35B9B4),
          brightness: Brightness.light,
        ),
      ),
      home: child,
    );
  }

  group('PadCare Authentication Suite', () {
    testWidgets('Welcome screen renders PadCare branding and no Nimbus', (
      tester,
    ) async {
      bool getStartedTapped = false;
      await tester.pumpWidget(
        testWrapper(
          Welcome(
            onGetStarted: () => getStartedTapped = true,
          ),
        ),
      );

      // Verify PadCare brand presence and no Nimbus
      expect(find.text('Welcome to PadCare'), findsOneWidget);
      expect(find.textContaining('Nimbus'), findsNothing);
      expect(
        find.textContaining('menstrual hygiene, emergency period care'),
        findsOneWidget,
      );

      // Tap get started
      await tester.tap(find.text('Get started'));
      await tester.pump();
      expect(getStartedTapped, isTrue);
    });

    testWidgets('SocialLogin renders Sign in to PadCare and no Nimbus', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const SocialLogin()));

      expect(find.text('Sign in to PadCare'), findsOneWidget);
      expect(find.textContaining('Nimbus'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Email'), findsOneWidget);
      expect(find.text('Create a new account'), findsOneWidget);
      expect(
        find.textContaining('By continuing you agree to PadCare\'s Terms and Privacy Policy.'),
        findsOneWidget,
      );
    });

    testWidgets('BiometricUnlock renders PadCare is locked and no Nimbus', (
      tester,
    ) async {
      bool unlocked = false;
      await tester.pumpWidget(
        testWrapper(
          BiometricUnlock(
            onUnlocked: () => unlocked = true,
          ),
        ),
      );

      expect(find.text('PadCare is locked'), findsOneWidget);
      expect(find.textContaining('Nimbus'), findsNothing);
      expect(find.text('Tap to unlock with Face ID or Touch ID'), findsOneWidget);
      expect(find.text('Use passcode instead'), findsOneWidget);

      // Tap fingerprint to trigger simulated scan
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(find.text('Scanning…'), findsOneWidget);

      // Advance time to complete simulated scan
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('Unlocked'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 450));
      expect(unlocked, isTrue);
    });

    testWidgets('LoginHero renders fields and toggles password visibility', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const LoginHero()));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to continue to your PadCare account'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);

      // Verify obscure text toggle
      final obscureToggle = find.byIcon(Icons.visibility_off);
      expect(obscureToggle, findsOneWidget);
      await tester.tap(obscureToggle);
      await tester.pump();
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('SignupTerms displays password strength and requires agreement', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const SignupTerms()));

      expect(find.text('Get started free with PadCare'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Strength: Too weak'), findsOneWidget);

      // Enter stronger password
      final passwordField = find.widgetWithText(TextField, 'Password');
      await tester.enterText(passwordField, 'P@ssw0rd123');
      await tester.pump();
      expect(find.text('Strength: Strong'), findsOneWidget);

      // The create account button is disabled before checking terms
      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      expect(submitButton.onPressed, isNull);

      // Check terms checkbox
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      final submitButtonEnabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      expect(submitButtonEnabled.onPressed, isNotNull);
    });

    testWidgets('PinLock enters digits and unlocks with 1234', (
      tester,
    ) async {
      bool unlocked = false;
      await tester.pumpWidget(
        testWrapper(
          PinLock(
            correctPin: '1234',
            onUnlocked: () => unlocked = true,
          ),
        ),
      );

      expect(find.text('Enter your PIN'), findsOneWidget);
      expect(find.text('Hint: 1234'), findsOneWidget);
      expect(find.text('Use biometrics'), findsOneWidget);

      // Tap 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
      expect(unlocked, isTrue);
    });

    testWidgets('PinCreate and PinConfirm share identical enter-your-pin styling and validate matching PIN', (
      tester,
    ) async {
      String? confirmedPinResult;
      await tester.pumpWidget(
        testWrapper(
          PinCreate(
            onPinCreated: (pin) => confirmedPinResult = pin,
          ),
        ),
      );

      // Verify same style on PinCreate
      expect(find.text('Create your PIN'), findsOneWidget);
      expect(find.text('Choose a 4-digit PIN for quick access'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap 5, 6, 7, 8 on PinCreate
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();

      // Completes creation and auto-navigates to PinConfirm
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify same style on PinConfirm
      expect(find.text('Confirm your PIN'), findsOneWidget);
      expect(find.text('Re-enter your 4-digit PIN to confirm'), findsOneWidget);
      expect(find.text('Start over'), findsOneWidget);

      // Enter matching PIN: 5, 6, 7, 8
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
      expect(confirmedPinResult, equals('5678'));
    });

    testWidgets('PinConfirm displays error message on mismatch', (
      tester,
    ) async {
      bool mismatchFired = false;
      await tester.pumpWidget(
        testWrapper(
          PinConfirm(
            initialPin: '1234',
            onMismatch: () => mismatchFired = true,
          ),
        ),
      );

      expect(find.text('Confirm your PIN'), findsOneWidget);

      // Enter mismatched PIN: 9, 9, 9, 9
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
      expect(mismatchFired, isTrue);
      expect(find.text("PINs don't match, try again"), findsOneWidget);
    });

    testWidgets('EmailVerification renders email and actions', (
      tester,
    ) async {
      bool openEmailTapped = false;
      bool resendTapped = false;
      await tester.pumpWidget(
        testWrapper(
          EmailVerification(
            email: 'amina@padcare.org',
            onOpenEmailApp: () => openEmailTapped = true,
            onResendEmail: () => resendTapped = true,
          ),
        ),
      );

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('amina@padcare.org'), findsOneWidget);
      expect(find.text('Open email app'), findsOneWidget);
      expect(find.text('Resend email'), findsOneWidget);

      await tester.tap(find.text('Open email app'));
      await tester.pump();
      expect(openEmailTapped, isTrue);

      await tester.tap(find.text('Resend email'));
      await tester.pump();
      expect(resendTapped, isTrue);
    });

    testWidgets('MagicLink toggles sent state and displays instructions', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const MagicLink()));

      expect(find.text('Passwordless login'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Email address'),
        'sarah@padcare.org',
      );
      await tester.tap(find.text('Send magic link'));
      await tester.pump();

      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.textContaining('sarah@padcare.org'), findsOneWidget);
      expect(find.text('Continue to PadCare'), findsOneWidget);
    });

    testWidgets('ResetPassword checks length, number, and matching passwords', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const ResetPassword()));

      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Contains a number'), findsOneWidget);
      expect(find.text('Passwords match'), findsOneWidget);

      final resetButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reset password'),
      );
      expect(resetButton.onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'New password'),
        'validPass123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'validPass123',
      );
      await tester.pump();

      final resetButtonValid = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reset password'),
      );
      expect(resetButtonValid.onPressed, isNotNull);
    });

    testWidgets('TwoFactor renders 6 digits and keypad', (
      tester,
    ) async {
      await tester.pumpWidget(
        testWrapper(
          const TwoFactor(targetContact: '•••• 7721'),
        ),
      );

      expect(find.text('Two-factor authentication'), findsOneWidget);
      expect(find.textContaining('•••• 7721'), findsOneWidget);
      expect(find.textContaining('Resend code in 0:'), findsOneWidget);

      // Enter digits using the keypad
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });
  });
}
