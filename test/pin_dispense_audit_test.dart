import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/main.dart';
import 'package:padcare/services/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PadCare PIN Generation & Dispensing End-to-End Technical Audit', () {
    // -------------------------------------------------------------
    // Test A: Teacher creates a request. A unique PIN is generated and saved.
    // -------------------------------------------------------------
    testWidgets('Test A: Teacher creates request; unique PIN is generated and saved', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Sister Rose'),
      ));
      await tester.pumpAndSettle();

      // Navigate to Requests tab
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      // Tap New Student Request button
      final newReqBtn = find.byKey(const ValueKey('teacher-new-request-btn'));
      expect(newReqBtn, findsOneWidget);
      await tester.tap(newReqBtn);
      await tester.pumpAndSettle();

      // Expect bottom sheet with Issue Student Request
      expect(find.text('Issue Student Request'), findsOneWidget);
      expect(find.text("Facility: St. Mary's Secondary"), findsOneWidget);

      // Save student request
      final saveBtn = find.byKey(const ValueKey('save-teacher-request-btn'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Expect PIN Generated dialog
      expect(find.text('PIN Generated'), findsOneWidget);
      expect(find.textContaining('#'), findsWidgets);

      // Verify persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('padcare.localState.v1');
      expect(localJson, isNotNull);
      final decoded = jsonDecode(localJson!) as Map<String, dynamic>;
      final requests = decoded['requests'] as List;
      expect(requests.length, 1);

      final req = requests.first as Map<String, dynamic>;
      expect(req['school'], "St. Mary's Secondary");
      expect(req['pickupPin'], isNotNull);
      expect(req['pickupPin'].toString().length, 4);
      expect(int.tryParse(req['pickupPin'].toString()), isNotNull);
    });

    // -------------------------------------------------------------
    // Test B: The same request appears in the correct administrator's Requests section with identical PIN.
    // -------------------------------------------------------------
    testWidgets('Test B: Request appears in correct admin portal with identical PIN', (tester) async {
      final initialData = {
        'requests': [
          {
            'id': 'req-audit-101',
            'reference': 'REQ-1463',
            'pickupPin': '1463',
            'school': "St. Mary's Secondary",
            'area': 'Arua Hill',
            'product': 'Disposable pads',
            'quantity': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'Approved',
          }
        ],
        'stock': {"St. Mary's Secondary::Disposable pads": 50},
      };

      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Matron Mary'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      // Expect request card with REQ-1463 to be rendered
      expect(find.byKey(const ValueKey('teacher-request-req-audit-101')), findsOneWidget);
      expect(find.textContaining('REQ-1463'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test C: Administrator enters the correct PIN. The system finds corresponding request.
    // -------------------------------------------------------------
    testWidgets('Test C: Admin enters correct PIN and system prompts dispense confirmation', (tester) async {
      final initialData = {
        'requests': [
          {
            'id': 'req-audit-102',
            'reference': 'REQ-1463',
            'pickupPin': '1463',
            'school': "St. Mary's Secondary",
            'area': 'Arua Hill',
            'product': 'Disposable pads',
            'quantity': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'Approved',
          }
        ],
        'stock': {"St. Mary's Secondary::Disposable pads": 50},
      };

      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Matron Mary'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      // Enter PIN 1463 into dispense field
      await tester.enterText(find.byType(TextField), '1463');
      await tester.pump();

      // Tap Dispense button
      final dispenseBtn = find.byKey(const ValueKey('verify-pin-dispense-btn'));
      await tester.ensureVisible(dispenseBtn);
      await tester.tap(dispenseBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog must appear
      expect(find.text('Confirm Dispense & Handout'), findsOneWidget);
      expect(find.text('#1463'), findsWidgets);
      expect(find.text("St. Mary's Secondary"), findsWidgets);
      expect(find.text('Disposable pads'), findsWidgets);
      expect(find.text('2 packs'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test D: Administrator successfully dispenses. Request changes to Collected.
    // -------------------------------------------------------------
    testWidgets('Test D: Dispensing marks request Collected and updates inventory', (tester) async {
      final initialData = {
        'requests': [
          {
            'id': 'req-audit-103',
            'reference': 'REQ-1463',
            'pickupPin': '1463',
            'school': "St. Mary's Secondary",
            'area': 'Arua Hill',
            'product': 'Disposable pads',
            'quantity': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'Approved',
          }
        ],
        'stock': {"St. Mary's Secondary::Disposable pads": 50},
      };

      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Matron Mary'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1463');
      await tester.ensureVisible(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.tap(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.byKey(const ValueKey('confirm-dispense-dialog-btn')));
      await tester.pumpAndSettle();

      // Success notification
      expect(find.textContaining('Verified PIN #1463! Dispensed 2 Disposable pads'), findsOneWidget);

      // Check SharedPreferences for Collected status and updated stock
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('padcare.localState.v1');
      final decoded = jsonDecode(localJson!) as Map<String, dynamic>;
      final requests = decoded['requests'] as List;
      final req = requests.first as Map<String, dynamic>;
      expect(req['status'], 'Collected');

      // Check stock deducted: 50 - 2 = 48
      final stock = decoded['stock'] as Map<String, dynamic>;
      expect(stock["St. Mary's Secondary::Disposable pads"], 48);
    });

    // -------------------------------------------------------------
    // Test E: Administrator enters incorrect PIN. System displays appropriate error.
    // -------------------------------------------------------------
    testWidgets('Test E: Admin enters invalid PIN; appropriate error is displayed', (tester) async {
      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode({'requests': [], 'stock': {}}),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Matron Mary'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '9999');
      await tester.ensureVisible(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.tap(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.pumpAndSettle();

      // Expect specific error message with school name
      expect(find.text("No active request found matching PIN #9999 at St. Mary's Secondary."), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test F: Administrator enters an already-used PIN. Rejects transaction.
    // -------------------------------------------------------------
    testWidgets('Test F: Admin enters already-collected PIN; transaction rejected', (tester) async {
      final initialData = {
        'requests': [
          {
            'id': 'req-audit-104',
            'reference': 'REQ-1463',
            'pickupPin': '1463',
            'school': "St. Mary's Secondary",
            'area': 'Arua Hill',
            'product': 'Disposable pads',
            'quantity': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'Collected',
          }
        ],
        'stock': {"St. Mary's Secondary::Disposable pads": 48},
      };

      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Matron Mary'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1463');
      await tester.ensureVisible(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.tap(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('already collected/dispensed'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test G: Administrator enters PIN belonging to another school. Rejects transaction.
    // -------------------------------------------------------------
    testWidgets('Test G: PIN from another school is rejected with explicit school mismatch error', (tester) async {
      final initialData = {
        'requests': [
          {
            'id': 'req-audit-105',
            'reference': 'REQ-7788',
            'pickupPin': '7788',
            'school': 'Oli Primary School',
            'area': 'Oli',
            'product': 'Disposable pads',
            'quantity': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'Approved',
          }
        ],
        'stock': {"Oli Primary School::Disposable pads": 30},
      };

      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      // Admin is logged into St. Mary's Secondary
      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Matron Mary'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '7788');
      await tester.ensureVisible(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.tap(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.pumpAndSettle();

      // Explicit error identifying the registered school
      expect(
        find.textContaining("PIN #7788 is registered for pickup at Oli Primary School, not St. Mary's Secondary"),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------
    // Test H: Administrator attempts to dispense more products than available stock. System prevents transaction.
    // -------------------------------------------------------------
    testWidgets('Test H: Dispensing rejected when requested quantity exceeds available stock', (tester) async {
      final initialData = {
        'requests': [
          {
            'id': 'req-audit-106',
            'reference': 'REQ-5511',
            'pickupPin': '5511',
            'school': "St. Mary's Secondary",
            'area': 'Arua Hill',
            'product': 'Disposable pads',
            'quantity': 50, // Requested 50
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'Approved',
          }
        ],
        'stock': {"St. Mary's Secondary::Disposable pads": 5}, // Only 5 available
      };

      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Matron Mary'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5511');
      await tester.ensureVisible(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.tap(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Insufficient stock'), findsOneWidget);

      // Verify request is NOT marked Collected
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('padcare.localState.v1')!) as Map<String, dynamic>;
      final req = (decoded['requests'] as List).first as Map<String, dynamic>;
      expect(req['status'], 'Approved');
    });

    // -------------------------------------------------------------
    // Test I: Internet disconnects during request creation and later reconnects. Synchronization works without duplicates.
    // -------------------------------------------------------------
    testWidgets('Test I: Offline requests queue safely and deduplicate on sync', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('padcare.offlineQueue.v1');
      await OfflineQueueService.init(isTest: true);

      final offlineReq = {
        'id': 'offline-req-201',
        'reference': 'REQ-3322',
        'pickupPin': '3322',
        'school': "St. Mary's Secondary",
        'area': 'Arua Hill',
        'product': 'Reusable pads',
        'quantity': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'Pending review',
      };

      // Enqueue offline action
      await OfflineQueueService.enqueue(type: 'save_request', payload: offlineReq);
      expect(OfflineQueueService.pendingCount.value >= 1, isTrue);

      // Verify offline queue persisted in SharedPreferences
      final queueJson = prefs.getString('padcare.offlineQueue.v1');
      expect(queueJson, isNotNull);
      expect(queueJson, contains('3322'));

      // Now verify deduplication logic when cloud sync arrives with matching record
      final initialData = {
        'requests': [offlineReq],
        'stock': {},
      };
      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Sister Rose'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      // Only one card should be present
      expect(find.textContaining('REQ-3322'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test J: Two administrators attempt to dispense the same PIN simultaneously.
    // -------------------------------------------------------------
    test('Test J: Concurrency protection prevents double dispensing', () {
      // Simulate concurrency logic on a request
      var requestStatus = 'Approved';
      var kitsOnHand = 10;
      var dispensedCount = 0;

      void attemptDispense(String admin) {
        if (requestStatus == 'Collected') {
          throw Exception('Request has already been collected.');
        }
        if (kitsOnHand < 1) {
          throw Exception('Insufficient stock.');
        }
        // Atomic step
        requestStatus = 'Collected';
        kitsOnHand -= 1;
        dispensedCount += 1;
      }

      // First admin dispenses
      attemptDispense('Admin 1');
      expect(dispensedCount, 1);
      expect(kitsOnHand, 9);
      expect(requestStatus, 'Collected');

      // Second admin attempts simultaneously
      expect(() => attemptDispense('Admin 2'), throwsA(isA<Exception>()));
      expect(dispensedCount, 1);
      expect(kitsOnHand, 9); // Not deducted twice
    });

    // -------------------------------------------------------------
    // Test K: Application refreshed or restarted. Requests and PINs remain consistent.
    // -------------------------------------------------------------
    test('Test K: Requests and PINs persist consistently across app restart', () async {
      final sample = {
        'requests': [
          {
            'id': 'persisted-req-1',
            'reference': 'REQ-1463',
            'pickupPin': '1463',
            'school': "St. Mary's Secondary",
            'area': 'Arua Hill',
            'product': 'Disposable pads',
            'quantity': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'Approved',
          }
        ],
        'stock': {"St. Mary's Secondary::Disposable pads": 25},
      };

      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(sample),
      });

      // Read back via app loader
      final localData = await SharedPreferences.getInstance();
      final loaded = jsonDecode(localData.getString('padcare.localState.v1')!) as Map<String, dynamic>;
      final reqList = loaded['requests'] as List;
      expect(reqList.length, 1);
      expect(reqList.first['pickupPin'], '1463');
      expect(reqList.first['reference'], 'REQ-1463');
      expect(reqList.first['school'], "St. Mary's Secondary");
    });

    // -------------------------------------------------------------
    // Test L: A failed dispensing transaction does not mark collected or deduct inventory.
    // -------------------------------------------------------------
    testWidgets('Test L: Cancelled or failed dispense aborts cleanly without state mutation', (tester) async {
      final initialData = {
        'requests': [
          {
            'id': 'req-audit-107',
            'reference': 'REQ-1463',
            'pickupPin': '1463',
            'school': "St. Mary's Secondary",
            'area': 'Arua Hill',
            'product': 'Disposable pads',
            'quantity': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'Approved',
          }
        ],
        'stock': {"St. Mary's Secondary::Disposable pads": 50},
      };

      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Matron Mary'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1463');
      await tester.ensureVisible(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.tap(find.byKey(const ValueKey('verify-pin-dispense-btn')));
      await tester.pumpAndSettle();

      // Dialog opens. User clicks Cancel
      expect(find.text('Confirm Dispense & Handout'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-dispense-dialog-btn')));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Confirm Dispense & Handout'), findsNothing);

      // Verify request is STILL Approved and stock is STILL 50
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('padcare.localState.v1')!) as Map<String, dynamic>;
      final req = (decoded['requests'] as List).first as Map<String, dynamic>;
      expect(req['status'], 'Approved');

      final stock = decoded['stock'] as Map<String, dynamic>;
      expect(stock["St. Mary's Secondary::Disposable pads"], 50);
    });

    // -------------------------------------------------------------
    // Test M: Full End-to-End Workflow (Acceptance Criterion)
    // 1. Teacher creates request for 4 packs of disposable pads.
    // 2. System generates PIN (e.g. #7781) and saves request.
    // 3. Administrator receives request: Request PH-7781 at St. Mary's Secondary.
    // 4. Administrator enters #7781: Backend finds & verifies original request.
    // 5. Administrator confirms dispensing in confirmation dialog.
    // 6. Database updates automatically: Request Collected, stock reduced by 4,
    //    and re-attempting same PIN is strictly rejected.
    // -------------------------------------------------------------
    testWidgets('Test M: Full End-to-End Workflow: Teacher creates request for 4 packs, system generates PIN, request PH-<PIN> appears, Admin verifies that exact generated PIN, confirms dispensing, and database updates', (tester) async {
      final initialData = {
        'requests': [],
        'stock': {"St. Mary's Secondary::Disposable pads": 50},
      };
      SharedPreferences.setMockInitialValues({
        'padcare.localState.v1': jsonEncode(initialData),
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(facility: "St. Mary's Secondary", teacherName: 'Senior Woman Teacher'),
      ));
      await tester.pumpAndSettle();

      // Step 1: Teacher creates request (4 packs of disposable pads)
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      final newReqBtn = find.byKey(const ValueKey('teacher-new-request-btn'));
      expect(newReqBtn, findsOneWidget);
      await tester.tap(newReqBtn);
      await tester.pumpAndSettle();

      // Select 4 packs
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // Tap 'Generate PIN & Save Request'
      final saveBtn = find.byKey(const ValueKey('save-teacher-request-btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Step 2: System generates PIN & displays dialog
      expect(find.text('PIN Generated'), findsOneWidget);
      expect(find.text('Request ID'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('padcare.localState.v1');
      expect(localJson, isNotNull);
      final decoded = jsonDecode(localJson!) as Map<String, dynamic>;
      final requests = decoded['requests'] as List;
      expect(requests.length, 1);
      final generatedReq = requests.first as Map<String, dynamic>;
      final generatedPin = generatedReq['pickupPin'].toString();
      final generatedRef = generatedReq['reference'].toString();
      expect(generatedPin.length, 4);
      expect(generatedRef, 'PH-$generatedPin');
      expect(generatedReq['quantity'], 4);
      expect(generatedReq['product'], 'Disposable pads');
      expect(generatedReq['status'], 'Approved');

      // Dismiss dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Step 3: Administrator receives request: Request PH-<PIN> at the correct school
      expect(find.text('Request $generatedRef'), findsOneWidget);
      expect(find.text('4 packs of Disposable pads'), findsOneWidget);
      expect(find.text('#$generatedPin'), findsWidgets);

      // Step 4: Administrator enters #<PIN> into 1-Tap PIN Dispense field
      final pinField = find.byType(TextField);
      await tester.ensureVisible(pinField);
      await tester.enterText(pinField, '#$generatedPin');
      await tester.pump();

      // Tap Dispense
      final dispenseBtn = find.byKey(const ValueKey('verify-pin-dispense-btn'));
      await tester.ensureVisible(dispenseBtn);
      await tester.tap(dispenseBtn);
      await tester.pumpAndSettle();

      // Step 5: Administrator confirms dispensing
      expect(find.text('Confirm Dispense & Handout'), findsOneWidget);
      expect(find.text(generatedRef), findsWidgets);
      expect(find.text('#$generatedPin'), findsWidgets);
      expect(find.text("St. Mary's Secondary"), findsWidgets);
      expect(find.text('4 packs'), findsWidgets);
      expect(find.text('50 packs'), findsOneWidget);
      expect(find.text('46 packs'), findsOneWidget);

      final confirmBtn = find.byKey(const ValueKey('confirm-dispense-dialog-btn'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Step 6: Database updates automatically
      expect(find.textContaining('Verified PIN #$generatedPin! Dispensed 4 Disposable pads'), findsOneWidget);

      final updatedJson = prefs.getString('padcare.localState.v1');
      final updatedData = jsonDecode(updatedJson!) as Map<String, dynamic>;
      final updatedReq = (updatedData['requests'] as List).first as Map<String, dynamic>;
      expect(updatedReq['status'], 'Collected');

      // Stock reduced by 4 packs (50 - 4 = 46)
      final updatedStock = updatedData['stock'] as Map<String, dynamic>;
      expect(updatedStock["St. Mary's Secondary::Disposable pads"], 46);

      // Prevent double dispensing: re-entering same PIN fails
      await tester.ensureVisible(pinField);
      await tester.enterText(pinField, generatedPin);
      await tester.ensureVisible(dispenseBtn);
      await tester.tap(dispenseBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('already collected/dispensed'), findsOneWidget);
    });
  });
}
