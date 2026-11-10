import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/main.dart';
import 'package:padcare/services/firebase_service.dart';
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
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _TestHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PadCare Admin Passkey Protection Tests', () {
    test('FirestoreService.verifyAdminPasskey validates master passkeys correctly', () {
      expect(FirestoreService.verifyAdminPasskey('PadCareAdmin@2026'), isTrue);
      expect(FirestoreService.verifyAdminPasskey('PadCare2026!'), isTrue);
      expect(FirestoreService.verifyAdminPasskey('PadCareAdmin2026'), isTrue);
      expect(FirestoreService.verifyAdminPasskey('padcare@admin2026'), isTrue);
      expect(FirestoreService.verifyAdminPasskey(' PadCareAdmin@2026 '), isTrue);

      expect(FirestoreService.verifyAdminPasskey('wrongPassword'), isFalse);
      expect(FirestoreService.verifyAdminPasskey('123456'), isFalse);
      expect(FirestoreService.verifyAdminPasskey('teacher123'), isFalse);
      expect(FirestoreService.verifyAdminPasskey(''), isFalse);
    });

    testWidgets('TeacherPendingApprovalScreen blocks unauthorized access and allows valid admin passkey', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pre-save pending profile in FirestoreService offline cache
      await FirestoreService.saveUserProfile(const UserProfile(
        uid: 'teacher-pending-test-uid',
        email: 'teacher@school.org',
        displayName: 'Tr. Agnes',
        role: 'teacher',
        school: "St. Mary's Secondary",
        authorized: false,
        status: 'pending_approval',
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherPendingApprovalScreen(
            teacherName: 'Tr. Agnes',
            school: "St. Mary's Secondary",
            uid: 'teacher-pending-test-uid',
            email: 'teacher@school.org',
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Admin Quick-Authorize button
      final adminBtn = find.byKey(const ValueKey('admin-quick-authorize-btn'));
      expect(adminBtn, findsOneWidget);

      // Tap button to open password dialog
      await tester.tap(adminBtn);
      await tester.pumpAndSettle();

      // Verify dialog appears with password field
      expect(find.text('Admin Authorization'), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-passkey-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('confirm-admin-auth-btn')), findsOneWidget);

      // Test 1: Enter wrong password
      await tester.enterText(find.byKey(const ValueKey('admin-passkey-field')), 'wrongPass');
      await tester.tap(find.byKey(const ValueKey('confirm-admin-auth-btn')));
      await tester.pumpAndSettle();

      // Verify access denied error is displayed
      expect(find.text('Incorrect admin password. Access denied.'), findsOneWidget);

      // Verify profile is still unauthorized
      var profile = await FirestoreService.getUserProfile('teacher-pending-test-uid');
      expect(profile!.authorized, isFalse);

      // Test 2: Enter correct admin password
      await tester.enterText(find.byKey(const ValueKey('admin-passkey-field')), 'PadCareAdmin@2026');
      await tester.tap(find.byKey(const ValueKey('confirm-admin-auth-btn')));
      await tester.pumpAndSettle();

      // Verify profile is now authorized
      profile = await FirestoreService.getUserProfile('teacher-pending-test-uid');
      expect(profile!.authorized, isTrue);
      expect(profile.status, 'approved');

      // Verify user transitioned to HomeScreen with verified school staff badge
      expect(find.text('STAFF DASHBOARD'), findsOneWidget);
      expect(find.textContaining('Verified School Staff: Tr. Agnes'), findsOneWidget);
    });
  });
}
