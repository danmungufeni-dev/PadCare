import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/auth/auth_screens.dart';
import 'package:padcare/services/firebase_service.dart';
import 'package:padcare/services/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kTransparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.physicalSize =
        const Size(800, 1400);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.devicePixelRatio =
        1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetDevicePixelRatio();
  });

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

      expect(find.text('Welcome to PadCare'), findsOneWidget);
      expect(find.textContaining('Nimbus'), findsNothing);
      expect(
        find.textContaining('menstrual hygiene, emergency period care'),
        findsOneWidget,
      );

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

      await tester.tap(find.byIcon(Icons.fingerprint));
      await tester.pump();
      expect(find.text('Scanning…'), findsOneWidget);

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
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);

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

      final passwordField = find.widgetWithText(TextField, 'Password');
      await tester.enterText(passwordField, 'P@ssw0rd123');
      await tester.pump();
      expect(find.text('Strength: Strong'), findsOneWidget);

      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      expect(submitButton.onPressed, isNull);

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

      expect(find.text('Create your PIN'), findsOneWidget);
      expect(find.text('Choose a 4-digit PIN for quick access'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your PIN'), findsOneWidget);
      expect(find.text('Re-enter your 4-digit PIN to confirm'), findsOneWidget);
      expect(find.text('Start over'), findsOneWidget);

      await tester.tap(find.text('5').last);
      await tester.pump();
      await tester.tap(find.text('6').last);
      await tester.pump();
      await tester.tap(find.text('7').last);
      await tester.pump();
      await tester.tap(find.text('8').last);
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

      await tester.tap(find.text('5').last);
      await tester.pump();
      expect(find.text('5'), findsNWidgets(2));
    });

    testWidgets('LoginHero displays Firebase Connected badge and demo buttons', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const LoginHero()));

      expect(find.text('Firebase Auth & Storage Connected'), findsOneWidget);
      expect(find.text('Dan Mungufeni'), findsOneWidget);
      expect(find.text('Abeti Nicholas'), findsOneWidget);
    });

    testWidgets('SignupTerms displays avatar selector and saves profile with photo', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const SignupTerms()));

      expect(find.text('Profile Avatar (Synced with Firebase Storage)'), findsOneWidget);
    });

    test('AuthService demo sign in returns UserProfile and photoUrl', () async {
      final resultDan = await AuthService.signIn(
        email: 'devgtnation@gmail.com',
        password: 'any',
      );
      expect(resultDan.isSuccess, isTrue);
      expect(resultDan.photoUrl, isNotNull);
      expect(resultDan.profile?.role, equals('teacher'));
      expect(resultDan.profile?.displayName, contains('Dan Mungufeni'));

      final resultNicholas = await AuthService.signIn(
        email: 'abetinichlas@gmail.com',
        password: 'any',
      );
      expect(resultNicholas.isSuccess, isTrue);
      expect(resultNicholas.photoUrl, isNotNull);
      expect(resultNicholas.profile?.role, equals('parent'));
      expect(resultNicholas.profile?.displayName, contains('Nicholas'));
    });

    test('StorageService handles avatar upload and caching safely', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final url = await StorageService.uploadProfileAvatar(
        uid: 'test-user-123',
        bytes: fakeBytes,
      );
      expect(url, isNotNull);

      final retrievedUrl = await StorageService.getProfileAvatarUrl('test-user-123');
      expect(retrievedUrl, equals(url));
    });

    test('UserProfile JSON serialization preserves photoUrl and phoneNumber', () {
      final profile = UserProfile(
        uid: 'uid-abc',
        email: 'nurse@padcare.org',
        displayName: 'Arua Nurse',
        role: 'teacher',
        school: "St. Mary's Secondary",
        authorized: true,
        status: 'approved',
        photoUrl: 'https://padcare.org/avatar.jpg',
        phoneNumber: '+256778123456',
      );

      final json = profile.toJson();
      expect(json['photoUrl'], equals('https://padcare.org/avatar.jpg'));
      expect(json['phoneNumber'], equals('+256778123456'));

      final reconstructed = UserProfile.fromJson(json);
      expect(reconstructed.photoUrl, equals(profile.photoUrl));
      expect(reconstructed.phoneNumber, equals(profile.phoneNumber));
      expect(reconstructed.displayName, equals('Arua Nurse'));
    });

    test('OfflineCacheService stores and retrieves educational guides & facilities', () async {
      SharedPreferences.setMockInitialValues({});
      final sampleGuides = [
        {
          'title': 'Period Hygiene Basics',
          'tag': 'Hygiene',
          'category': 'Hygiene',
          'content': ['Wash hands thoroughly', 'Change pad every 4-6 hours'],
        }
      ];

      final success = await OfflineCacheService.preCacheAllResources(guides: sampleGuides);
      expect(success, isTrue);
      expect(OfflineCacheService.isOfflineReady.value, isTrue);

      final cached = await OfflineCacheService.getCachedGuides();
      expect(cached, isNotNull);
      expect(cached!.length, equals(1));
      expect(cached.first['title'], equals('Period Hygiene Basics'));
    });

    testWidgets('LoginHero provides 1-Tap Quick Demo Logins chips for Dan M and Nicholas A', (tester) async {
      await tester.pumpWidget(testWrapper(const LoginHero()));
      expect(find.text('1-Tap Quick Demo Logins'), findsOneWidget);
      expect(find.text('Dan M. (Teacher)'), findsOneWidget);
      expect(find.text('Nicholas A. (Parent)'), findsOneWidget);

      await tester.tap(find.text('Dan M. (Teacher)'));
      await tester.pump();
      expect(find.text('devgtnation@gmail.com'), findsOneWidget);
    });

    testWidgets('EmailVerification renders email and blocks unverified progression', (tester) async {
      PadCareAuthNavigator.testMode = false;
      bool verifiedCallbackCalled = false;

      await tester.pumpWidget(
        testWrapper(
          EmailVerification(
            email: 'testuser@padcare.org',
            onVerified: () => verifiedCallbackCalled = true,
          ),
        ),
      );

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('testuser@padcare.org'), findsOneWidget);
      expect(find.text('Open email app'), findsOneWidget);
      expect(find.text("I've verified, continue to PadCare"), findsOneWidget);

      // Tap continue when unverified
      await tester.tap(find.text("I've verified, continue to PadCare"));
      await tester.pumpAndSettle();

      // Ensure error was presented and callback was NOT triggered
      expect(verifiedCallbackCalled, isFalse);
      expect(find.textContaining('Email not yet verified'), findsWidgets);
    });

    testWidgets('EmailVerification proceeds smoothly when testMode/verified is active', (tester) async {
      PadCareAuthNavigator.testMode = true;
      bool verifiedCallbackCalled = false;

      await tester.pumpWidget(
        testWrapper(
          EmailVerification(
            email: 'verified@padcare.org',
            onVerified: () => verifiedCallbackCalled = true,
          ),
        ),
      );

      await tester.tap(find.text("I've verified, continue to PadCare"));
      await tester.pumpAndSettle();

      expect(verifiedCallbackCalled, isTrue);
    });
  });
}
