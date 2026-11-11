import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/auth/auth_screens.dart';
import 'package:padcare/main.dart';
import 'package:padcare/services/school_service.dart';
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

  group('PadCare School Facility Registration Tests', () {
    test('SchoolService registers and retrieves new school correctly', () async {
      final newSchool = SchoolModel(
        schoolId: 'ombaci-college',
        name: 'St. Joseph College Ombaci',
        district: 'Arua',
        subCounty: 'Ayivu',
        contactPhone: '+256772123456',
        createdAt: DateTime.now(),
      );

      await SchoolService.saveSchool(newSchool);
      final retrieved = await SchoolService.getSchool('ombaci-college');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'St. Joseph College Ombaci');
      expect(retrieved.subCounty, 'Ayivu');
      expect(SchoolService.cachedSchoolNames, contains('St. Joseph College Ombaci'));
    });

    testWidgets('SignupTerms allows teacher to add a new school inline and selects it', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SignupTerms(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Teacher role
      final teacherBtn = find.text('Teacher');
      expect(teacherBtn, findsOneWidget);
      await tester.tap(teacherBtn);
      await tester.pumpAndSettle();

      // Check that "Can't find your school? Add a new school" button is visible
      final toggleAddSchoolBtn = find.byKey(const ValueKey('toggle-add-school-btn'));
      expect(toggleAddSchoolBtn, findsOneWidget);

      // Tap to expand add school form
      await tester.tap(toggleAddSchoolBtn);
      await tester.pumpAndSettle();

      // Verify the add school form fields appear
      expect(find.byKey(const ValueKey('new-school-name-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('new-school-passkey-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('save-new-school-btn')), findsOneWidget);

      // Enter new school name
      await tester.enterText(
        find.byKey(const ValueKey('new-school-name-field')),
        'Jiako Primary School',
      );
      await tester.pumpAndSettle();

      // Attempt to save with invalid admin passkey
      await tester.enterText(
        find.byKey(const ValueKey('new-school-passkey-field')),
        'WrongPassword123',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-new-school-btn')));
      await tester.pumpAndSettle();

      // Expect rejection error
      expect(find.textContaining('Incorrect admin password'), findsOneWidget);

      // Now enter valid admin passkey
      await tester.enterText(
        find.byKey(const ValueKey('new-school-passkey-field')),
        'PadCare2026!',
      );
      await tester.pumpAndSettle();

      // Save the new school
      await tester.tap(find.byKey(const ValueKey('save-new-school-btn')));
      await tester.pumpAndSettle();

      // Check that the new school is saved in SchoolService
      final savedSchool = await SchoolService.getSchool('Jiako Primary School');
      expect(savedSchool, isNotNull);
      expect(savedSchool!.name, 'Jiako Primary School');

      // Check feedback snackbar
      expect(find.text('🎉 School "Jiako Primary School" added and selected!'), findsOneWidget);
    });

    testWidgets('HomeScreen shows School Distribution Network card and allows adding school', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            facility: "St. Mary's Secondary",
            teacherName: 'Sister Agnes',
            onSignOut: () {},
            isVerifiedStaff: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify School Distribution Network card is visible
      expect(find.text('School Distribution Network'), findsOneWidget);
      expect(find.byKey(const ValueKey('staff-add-school-btn')), findsOneWidget);

      // Tap Add School button
      await tester.tap(find.byKey(const ValueKey('staff-add-school-btn')));
      await tester.pumpAndSettle();

      // Verify modal opens
      expect(find.text('Register New School'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-school-modal-name')), findsOneWidget);

      // Enter school details
      await tester.enterText(
        find.byKey(const ValueKey('add-school-modal-name')),
        'Arua Secondary School',
      );
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.byKey(const ValueKey('submit-add-school-btn')));
      await tester.pumpAndSettle();

      // Check that the school was saved
      final aruaSec = await SchoolService.getSchool('Arua Secondary School');
      expect(aruaSec, isNotNull);
      expect(aruaSec!.name, 'Arua Secondary School');

      // Verify snackbar
      expect(find.text('🎉 School "Arua Secondary School" registered successfully in PadCare!'), findsOneWidget);
    });
  });
}
