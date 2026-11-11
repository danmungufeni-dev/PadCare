import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padcare/services/inventory_service.dart';
import 'package:padcare/services/notification_service.dart';
import 'package:padcare/services/offline_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Item 4: Batch & Shelf-Life Tracking Tests', () {
    test('InventoryItemModel tracks batch and shelf life correctly', () {
      final now = DateTime.now();
      final freshItem = InventoryItemModel(
        id: 'inv_1',
        schoolId: 'logiri-girls',
        productId: 'regular-pads',
        productName: 'PadCare Regular Sanitary Pads',
        availableQuantity: 50,
        lastUpdated: now,
        batchNumber: 'LOT-2025-08X',
        manufactureDate: now.subtract(const Duration(days: 30)),
        expiryDate: now.add(const Duration(days: 400)),
      );

      expect(freshItem.batchNumber, 'LOT-2025-08X');
      expect(freshItem.isExpired, isFalse);
      expect(freshItem.isExpiringSoon, isFalse);
      expect(freshItem.shelfLifeStatus, 'good');
      expect(freshItem.shelfLifeLabel, contains('Good'));

      final json = freshItem.toJson();
      expect(json['batchNumber'], 'LOT-2025-08X');
      final fromJson = InventoryItemModel.fromJson(json);
      expect(fromJson.batchNumber, 'LOT-2025-08X');
    });

    test('InventoryItemModel flags expiring soon (FIFO priority) and expired batches', () {
      final now = DateTime.now();
      
      // Expiring in 45 days -> expiring soon
      final nearExpiry = InventoryItemModel(
        id: 'inv_2',
        schoolId: 'mvara-secondary',
        productId: 'dignity-kits',
        productName: 'Reusable Dignity Kits',
        availableQuantity: 25,
        lastUpdated: now,
        batchNumber: 'LOT-2024-03A',
        expiryDate: now.add(const Duration(days: 45)),
      );

      expect(nearExpiry.isExpired, isFalse);
      expect(nearExpiry.isExpiringSoon, isTrue);
      expect(nearExpiry.shelfLifeStatus, 'expiring_soon');
      expect(nearExpiry.shelfLifeLabel, contains('FIFO Priority'));

      // Expired 10 days ago -> expired
      final expired = InventoryItemModel(
        id: 'inv_3',
        schoolId: 'offaka-secondary',
        productId: 'disposable-pads',
        productName: 'Disposable Pads',
        availableQuantity: 10,
        lastUpdated: now,
        batchNumber: 'LOT-2023-01Z',
        expiryDate: now.subtract(const Duration(days: 10)),
      );

      expect(expired.isExpired, isTrue);
      expect(expired.shelfLifeStatus, 'expired');
      expect(expired.shelfLifeLabel, 'EXPIRED - DO NOT DISPENSE');
    });

    test('DistributionRecordModel includes batch number for audit trail', () {
      final record = DistributionRecordModel(
        distributionId: 'dist_99',
        requestId: 'REQ-1234',
        reference: 'REF-1234',
        pickupPin: '1234',
        schoolId: 'logiri-girls',
        schoolName: 'Logiri Girls Secondary',
        productId: 'regular-pads',
        quantity: 2,
        dispensedBy: 'Sister Rose',
        dispensedAt: DateTime.now(),
        batchNumber: 'LOT-2025-08X',
      );

      expect(record.batchNumber, 'LOT-2025-08X');
      final json = record.toJson();
      expect(json['batchNumber'], 'LOT-2025-08X');
      final parsed = DistributionRecordModel.fromJson(json);
      expect(parsed.batchNumber, 'LOT-2025-08X');
    });
  });

  group('Item 5: Automated Restock Alerts Tests', () {
    test('checkAndGenerateRestockAlert generates critical alert when stock <= 50% threshold', () async {
      final alert = await NotificationService.checkAndGenerateRestockAlert(
        schoolId: 'logiri-girls',
        schoolName: 'Logiri Girls Secondary',
        currentStock: 12,
        threshold: 30,
      );

      expect(alert, isNotNull);
      expect(alert!.urgency, 'urgent');
      expect(alert.schoolName, 'Logiri Girls Secondary');
      expect(alert.title, contains('Critical Restock Alert'));
      expect(alert.currentStock, 12);
      expect(alert.threshold, 30);
    });

    test('checkAndGenerateRestockAlert generates warning alert when stock is between 51% and 100% of threshold', () async {
      final alert = await NotificationService.checkAndGenerateRestockAlert(
        schoolId: 'mvara-secondary',
        schoolName: 'Mvara Secondary',
        currentStock: 25,
        threshold: 30,
      );

      expect(alert, isNotNull);
      expect(alert!.urgency, 'warning');
      expect(alert.title, contains('Low Stock Warning'));
      expect(alert.currentStock, 25);
    });

    test('checkAndGenerateRestockAlert returns null when stock is above threshold', () async {
      final alert = await NotificationService.checkAndGenerateRestockAlert(
        schoolId: 'st-marys',
        schoolName: 'St. Mary\'s Secondary',
        currentStock: 100,
        threshold: 30,
      );

      expect(alert, isNull);
    });

    test('streamRestockAlerts yields active stock alerts', () async {
      final alerts = await NotificationService.streamRestockAlerts().first;
      expect(alerts.isNotEmpty, isTrue);
      expect(alerts.any((a) => a.schoolName == 'Logiri Girls Secondary'), isTrue);
    });
  });

  group('Item 2: Offline-First Local Stock & Dispensation Queue Tests', () {
    test('cacheSchoolStock and getCachedSchoolStock persist stock locally', () async {
      await OfflineCacheService.cacheSchoolStock('Logiri Girls Secondary', {
        'packsOnHand': 120,
        'kitsOnHand': 45,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      final cached = await OfflineCacheService.getCachedSchoolStock('Logiri Girls Secondary');
      expect(cached, isNotNull);
      expect(cached!['packsOnHand'], 120);
      expect(cached['kitsOnHand'], 45);
    });

    test('decrementLocalStock decrements cached packs and kits immediately', () async {
      await OfflineCacheService.cacheSchoolStock('Terego Secondary', {
        'packsOnHand': 50,
        'kitsOnHand': 20,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Dispense 5 packs
      await OfflineCacheService.decrementLocalStock('Terego Secondary', 'Disposable Pads', 5);
      var cached = await OfflineCacheService.getCachedSchoolStock('Terego Secondary');
      expect(cached!['packsOnHand'], 45);
      expect(cached['kitsOnHand'], 20);

      // Dispense 2 kits
      await OfflineCacheService.decrementLocalStock('Terego Secondary', 'Reusable Dignity Kit', 2);
      cached = await OfflineCacheService.getCachedSchoolStock('Terego Secondary');
      expect(cached!['packsOnHand'], 45);
      expect(cached['kitsOnHand'], 18);
    });

    test('recordOfflineDispensation decrements stock and enqueues sync task', () async {
      await OfflineCacheService.cacheSchoolStock('Offaka Secondary', {
        'packsOnHand': 30,
        'kitsOnHand': 15,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      await OfflineQueueService.recordOfflineDispensation(
        requestId: 'REQ-OFF-01',
        school: 'Offaka Secondary',
        product: 'Disposable Pads',
        quantity: 3,
        pin: '1234',
        dispensedBy: 'Teacher Grace',
        batchNumber: 'LOT-2025-08X',
      );

      // Verify stock was immediately decremented locally
      final cached = await OfflineCacheService.getCachedSchoolStock('Offaka Secondary');
      expect(cached!['packsOnHand'], 27);

      // Verify offline queue contains the task
      final queue = await OfflineQueueService.getPendingTasks();
      expect(queue.any((task) => task.type == 'offline_dispensation' && task.payload['requestId'] == 'REQ-OFF-01'), isTrue);
    });
  });
}
