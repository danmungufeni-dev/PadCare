import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/features/ngo/ngo_dashboard_screen.dart';
import 'package:padcare/services/firebase_service.dart';

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
        const Size(900, 1600);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF116B78),
          brightness: Brightness.light,
        ),
      ),
      home: child,
    );
  }

  group('PadCare NGO Partner Dashboard Tests', () {
    test('FirestoreService returns verified NGO profile for demo account', () {
      final profile = FirestoreService.getPreverifiedDemoProfile('ngo@padcare.org');
      expect(profile, isNotNull);
      expect(profile!.role, equals('ngo'));
      expect(profile.displayName, contains('UNFPA'));
      expect(profile.authorized, isTrue);
      expect(profile.status, equals('approved'));
    });

    testWidgets('NgoDashboardScreen renders title, partner badge, and KPI metrics', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          NgoDashboardScreen(
            ngoName: 'UNFPA Uganda',
            email: 'ngo@padcare.org',
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PadCare'), findsOneWidget);
      expect(find.text('NGO PORTAL'), findsOneWidget);
      expect(find.text('Verified Partner • Live Telemetry'), findsOneWidget);
      expect(find.text('Total Pads Distributed'), findsOneWidget);
      expect(find.text('Dignity Kits Distributed'), findsOneWidget);
      expect(find.text('Total Funding Raised'), findsOneWidget);
      expect(find.text('Fulfillment Integrity'), findsOneWidget);
    });

    testWidgets('NgoDashboardScreen supports tab navigation to Distributions and Donations', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          NgoDashboardScreen(
            ngoName: 'Plan International',
            email: 'partner@padcare.org',
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Distributions tab
      await tester.tap(find.text('Distributions'));
      await tester.pumpAndSettle();
      expect(find.text('Verified Pad Distributions'), findsOneWidget);
      expect(find.text('Encrypted PIN'), findsOneWidget);

      // Tap on Donations tab
      await tester.tap(find.text('Donations'));
      await tester.pumpAndSettle();
      expect(find.text('Donation & Grant Inflow Ledger'), findsOneWidget);
      expect(find.text('TOTAL FUNDS RECEIVED'), findsOneWidget);

      // Tap on Schools tab
      await tester.tap(find.text('Schools'));
      await tester.pumpAndSettle();
      expect(find.text('Partner School Facility Network'), findsOneWidget);
    });

    testWidgets('Impact Report dialog opens with complete audit log and copy button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          NgoDashboardScreen(
            ngoName: 'UNFPA Uganda',
            email: 'ngo@padcare.org',
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exportBtn = find.byKey(const ValueKey('export-audit-btn'));
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(find.text('Impact Audit Report'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });
  });
}
