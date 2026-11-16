import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/main.dart';
import 'package:padcare/services/geo_service.dart';
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
  @override
  void close({bool force = false}) {}
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

  group('GPS Capture for Schools, Hospitals, and Dispensing Centers Tests', () {
    test('SchoolModel and GeoService accurately capture and register GPS coordinates', () async {
      // 1. School with captured GPS in Ediofe
      final ediofeCoords = GeoService.getCoordinatesForSubCounty('Ediofe');
      final school = SchoolModel(
        schoolId: 'mvara-senior-secondary',
        name: 'Mvara Senior Secondary School',
        facilityType: 'School',
        subCounty: 'Ediofe',
        latitude: ediofeCoords.latitude,
        longitude: ediofeCoords.longitude,
        createdAt: DateTime.now(),
      );
      await SchoolService.saveSchool(school);

      final retrievedSchool = await SchoolService.getSchool('mvara-senior-secondary');
      expect(retrievedSchool, isNotNull);
      expect(retrievedSchool!.facilityType, 'School');
      expect(retrievedSchool.latitude, ediofeCoords.latitude);
      expect(retrievedSchool.longitude, ediofeCoords.longitude);
      final registeredSchoolCoord = GeoService.getFacilityCoordinates('mvara-senior-secondary');
      expect(registeredSchoolCoord.latitude, ediofeCoords.latitude);
      expect(registeredSchoolCoord.longitude, ediofeCoords.longitude);

      // 2. Hospital with captured GPS in Arua Central
      final hospitalCoords = GeoService.getCoordinatesForSubCounty('Arua Central');
      final hospital = SchoolModel(
        schoolId: 'arua-community-hospital',
        name: 'Arua Community Hospital',
        facilityType: 'Hospital',
        subCounty: 'Arua Central',
        latitude: hospitalCoords.latitude,
        longitude: hospitalCoords.longitude,
        createdAt: DateTime.now(),
      );
      await SchoolService.saveSchool(hospital);

      final retrievedHospital = await SchoolService.getSchool('arua-community-hospital');
      expect(retrievedHospital, isNotNull);
      expect(retrievedHospital!.facilityType, 'Hospital');
      expect(retrievedHospital.latitude, hospitalCoords.latitude);
      expect(retrievedHospital.longitude, hospitalCoords.longitude);

      // 3. Dispensing Center with captured GPS in Oli
      final oliCoords = GeoService.getCoordinatesForSubCounty('Oli');
      final dispenser = SchoolModel(
        schoolId: 'oli-youth-dispensing-hub',
        name: 'Oli Youth Dispensing Hub',
        facilityType: 'Dispensing Center',
        subCounty: 'Oli',
        latitude: oliCoords.latitude,
        longitude: oliCoords.longitude,
        createdAt: DateTime.now(),
      );
      await SchoolService.saveSchool(dispenser);

      final retrievedDispenser = await SchoolService.getSchool('oli-youth-dispensing-hub');
      expect(retrievedDispenser, isNotNull);
      expect(retrievedDispenser!.facilityType, 'Dispensing Center');
      expect(retrievedDispenser.latitude, oliCoords.latitude);
      expect(retrievedDispenser.longitude, oliCoords.longitude);
    });

    testWidgets('InteractiveAruaMap renders OpenStreetMap directly with NO canvas map or mode switch pill', (tester) async {
      final points = [
        const SupportPoint(
          id: 'test-school',
          name: 'Test Partner School',
          category: 'Schools',
          area: 'Arua Hill',
          distanceKm: 0.5,
          hours: 'Open 8:00 AM - 5:00 PM',
          inStock: true,
          isVerified: true,
          directions: 'Arua Hill Avenue',
          pinLabel: 'School',
          latitude: 3.0185,
          longitude: 30.9250,
        ),
        const SupportPoint(
          id: 'test-hospital',
          name: 'Test Regional Hospital',
          category: 'Clinics',
          area: 'Arua Central',
          distanceKm: 1.0,
          hours: 'Open 24/7',
          inStock: true,
          isVerified: true,
          directions: 'Hospital Road',
          pinLabel: 'Hospital',
          latitude: 3.0205,
          longitude: 30.9110,
        ),
        const SupportPoint(
          id: 'test-dispenser',
          name: 'Central Dispensing Hub',
          category: 'NGOs',
          area: 'Oli',
          distanceKm: 1.5,
          hours: 'Open 8:00 AM - 4:00 PM',
          inStock: true,
          isVerified: true,
          directions: 'Oli Division',
          pinLabel: 'Dispenser',
          latitude: 3.0298,
          longitude: 30.9172,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InteractiveAruaMap(
                points: points,
                selectedPoint: points.first,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify FlutterMap with OpenStreetMap is present
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);

      // 2. Verify Canvas map elements and mode switch pills are completely REMOVED
      expect(find.text('Offline Canvas'), findsNothing);
      expect(find.text('Streets'), findsNothing);
      expect(find.byIcon(Icons.palette_outlined), findsNothing);

      // 3. Verify Map pins for School, Hospital, and Dispensing Center render
      expect(find.byType(MapTeardropPin), findsNWidgets(3));
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Hospital'), findsOneWidget);
      expect(find.text('Dispenser'), findsOneWidget);

      // 4. Verify OpenStreetMap legal attribution
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    });

    testWidgets('Modal allows capturing GPS when adding Hospital or Dispensing Center', (tester) async {
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

      // Tap Add School / Facility button
      await tester.tap(find.byKey(const ValueKey('staff-add-school-btn')));
      await tester.pumpAndSettle();

      // Verify modal and GPS fields are present
      expect(find.byKey(const ValueKey('add-facility-type-dropdown')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-facility-lat-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-facility-lon-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture-facility-gps-btn')), findsOneWidget);
      expect(find.text('GPS Captured'), findsOneWidget);

      // Change subcounty to Ediofe
      await tester.tap(find.byKey(const ValueKey('add-school-modal-subcounty')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ediofe').last);
      await tester.pumpAndSettle();

      // Verify GPS coordinates updated automatically to Ediofe
      final ediofeCoords = GeoService.getCoordinatesForSubCounty('Ediofe');
      final latField = tester.widget<TextField>(find.byKey(const ValueKey('add-facility-lat-field')));
      expect(double.parse(latField.controller!.text), closeTo(ediofeCoords.latitude, 0.001));

      // Enter facility name and passkey
      await tester.enterText(
        find.byKey(const ValueKey('add-school-modal-name')),
        'Ediofe Community Health Center',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('add-school-modal-passkey')),
        'PadCare2026!',
      );
      await tester.pumpAndSettle();

      // Select Hospital
      await tester.tap(find.byKey(const ValueKey('add-facility-type-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🏥 Hospital / Health Center').last);
      await tester.pumpAndSettle();

      // Tap submit
      final submitBtn = find.byKey(const ValueKey('submit-add-school-btn'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify hospital was registered with captured GPS coordinates
      final registeredHospital = await SchoolService.getSchool('Ediofe Community Health Center');
      expect(registeredHospital, isNotNull);
      expect(registeredHospital!.facilityType, 'Hospital');
      expect(registeredHospital.latitude, closeTo(ediofeCoords.latitude, 0.001));
      expect(registeredHospital.longitude, closeTo(ediofeCoords.longitude, 0.001));
    });
  });
}
