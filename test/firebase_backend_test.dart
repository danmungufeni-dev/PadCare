import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/services/firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PadCare Complete Firebase Backend Service Tests', () {
    // -------------------------------------------------------------
    // Test 1: User Roles and Profile Model
    // -------------------------------------------------------------
    test('UserRole constants and UserProfileModel mapping', () {
      expect(UserRole.allRoles, containsAll(['teacher', 'school_admin', 'sponsor', 'super_admin', 'parent']));
      expect(UserRole.displayName(UserRole.teacher), 'Teacher');
      expect(UserRole.displayName(UserRole.schoolAdmin), 'School Matron / Administrator');
      expect(UserRole.displayName(UserRole.sponsor), 'Sponsor / Donor');
      expect(UserRole.displayName(UserRole.superAdmin), 'Platform Administrator');

      final profile = UserProfileModel(
        uid: 'user-audit-001',
        email: 'teacher@stmarys.org',
        fullName: 'Sister Agnes',
        role: UserRole.teacher,
        schoolId: 'st-marys-secondary',
        schoolName: "St. Mary's Secondary",
        accountStatus: 'active',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(profile.isTeacher, isTrue);
      expect(profile.isSchoolAdmin, isFalse);
      expect(profile.isApproved, isTrue);

      final json = profile.toJson();
      expect(json['uid'], 'user-audit-001');
      expect(json['role'], 'teacher');
      expect(json['schoolId'], 'st-marys-secondary');

      final deserialized = UserProfileModel.fromJson(json);
      expect(deserialized.uid, profile.uid);
      expect(deserialized.email, profile.email);
      expect(deserialized.fullName, profile.fullName);
      expect(deserialized.role, UserRole.teacher);
    });

    // -------------------------------------------------------------
    // Test 2: School Facility Management & Isolation
    // -------------------------------------------------------------
    test('SchoolModel and SchoolService registry', () async {
      final school = SchoolModel(
        schoolId: 'st-marys-secondary',
        name: "St. Mary's Secondary",
        district: 'Arua',
        subCounty: 'Arua Hill',
        status: 'active',
        assignedStaffUids: ['teacher-001', 'matron-001'],
        createdAt: DateTime.now(),
      );

      await SchoolService.saveSchool(school);
      final retrieved = await SchoolService.getSchool('st-marys-secondary');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, "St. Mary's Secondary");
      expect(retrieved.district, 'Arua');
      expect(retrieved.status, 'active');

      await SchoolService.updateSchoolStatus('st-marys-secondary', 'suspended');
      final updated = await SchoolService.getSchool('st-marys-secondary');
      expect(updated!.status, 'suspended');

      // Restore to active
      await SchoolService.updateSchoolStatus('st-marys-secondary', 'active');
    });

    // -------------------------------------------------------------
    // Test 3: Request Lifecycle Transitions
    // -------------------------------------------------------------
    test('RequestModel serialization and status handling', () {
      final request = RequestModel(
        requestId: 'REQ-7781',
        reference: 'PH-7781',
        teacherUid: 'teacher-101',
        teacherName: 'Sister Agnes',
        schoolId: 'st-marys-secondary',
        schoolName: "St. Mary's Secondary",
        productId: 'disposable-pads',
        productName: 'Disposable pads',
        quantity: 4,
        pickupPin: '7781',
        status: 'Pending',
        createdAt: DateTime.now(),
      );

      expect(request.isCollected, isFalse);
      expect(request.isApproved, isFalse);

      final approved = request.copyWith(status: 'Approved', approvedAt: DateTime.now());
      expect(approved.isApproved, isTrue);
      expect(approved.approvedAt, isNotNull);

      final collected = approved.copyWith(status: 'Collected', collectedAt: DateTime.now(), collectedBy: 'Matron Mary');
      expect(collected.isCollected, isTrue);
      expect(collected.collectedBy, 'Matron Mary');

      final json = collected.toJson();
      final roundtrip = RequestModel.fromJson(json);
      expect(roundtrip.reference, 'PH-7781');
      expect(roundtrip.pickupPin, '7781');
      expect(roundtrip.quantity, 4);
      expect(roundtrip.isCollected, isTrue);
    });

    // -------------------------------------------------------------
    // Test 4: Secure PIN Generation & Verification Logic
    // -------------------------------------------------------------
    test('SecurePinService generates valid 4-digit numeric PINs', () {
      for (int i = 0; i < 50; i++) {
        final pin = SecurePinService.generatePin();
        expect(pin.length, 4);
        expect(int.tryParse(pin), isNotNull);
        expect(int.parse(pin), inInclusiveRange(1000, 9999));
      }
    });

    test('PinRecordModel validation and expiry calculations', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final record = PinRecordModel(
        pin: '7781',
        requestId: 'REQ-7781',
        reference: 'PH-7781',
        schoolId: 'st-marys-secondary',
        productId: 'disposable-pads',
        quantity: 4,
        status: 'active',
        expiresAt: futureDate,
        createdAt: DateTime.now(),
      );

      expect(record.isActive, isTrue);

      final expiredRecord = PinRecordModel(
        pin: '7781',
        requestId: 'REQ-7781',
        reference: 'PH-7781',
        schoolId: 'st-marys-secondary',
        productId: 'disposable-pads',
        quantity: 4,
        status: 'active',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 31)),
      );

      expect(expiredRecord.isActive, isFalse);
    });

    // -------------------------------------------------------------
    // Test 5: Inventory & Distribution Tracking
    // -------------------------------------------------------------
    test('InventoryItemModel tracks low stock and quantities', () {
      final item = InventoryItemModel(
        id: 'st-marys-secondary_disposable-pads',
        schoolId: 'st-marys-secondary',
        productId: 'disposable-pads',
        productName: 'Disposable pads',
        availableQuantity: 8,
        lowStockThreshold: 10,
        lastUpdated: DateTime.now(),
      );

      expect(item.isLowStock, isTrue);
      expect(item.unit, 'packs');

      final json = item.toJson();
      final roundtrip = InventoryItemModel.fromJson(json);
      expect(roundtrip.availableQuantity, 8);
      expect(roundtrip.isLowStock, isTrue);
    });

    // -------------------------------------------------------------
    // Test 6: Sponsor Donations & Campaigns
    // -------------------------------------------------------------
    test('DonationModel and CampaignModel calculations', () {
      final donation = DonationModel(
        donationId: 'DON-1001',
        sponsorUid: 'sponsor-555',
        sponsorName: 'Global Dignity Fund',
        amountUGX: 250000,
        kitsFunded: 25,
        schoolName: "St. Mary's Secondary",
        paymentMethod: 'MoMo',
        paymentStatus: 'completed',
        transactionReference: 'TX-MOMO-99128',
        createdAt: DateTime.now(),
      );

      final json = donation.toJson();
      expect(json['amount'], 250000);
      expect(json['currency'], 'UGX');
      expect(json['kitsFunded'], 25);

      final campaign = CampaignModel(
        campaignId: 'arua-term1-kits',
        title: 'Term 1 Dignity Kits',
        description: 'Providing 500 kits',
        targetKits: 500,
        fundedKits: 250,
        targetUGX: 25000000,
        raisedUGX: 12500000,
      );

      expect(campaign.progress, 0.5); // 50% funded
    });

    // -------------------------------------------------------------
    // Test 7: Analytics Event & Notification Serialization
    // -------------------------------------------------------------
    test('NotificationItemModel serialization', () {
      final notif = NotificationItemModel(
        id: 'notif-101',
        recipientUid: 'teacher-101',
        title: 'Request PH-7781 Ready for Pickup',
        body: '4 packs of Disposable pads are ready in the Matron office.',
        type: 'request_update',
        createdAt: DateTime.now(),
      );

      expect(notif.read, isFalse);
      final json = notif.toJson();
      final roundtrip = NotificationItemModel.fromJson(json);
      expect(roundtrip.title, notif.title);
      expect(roundtrip.type, 'request_update');
      expect(roundtrip.read, isFalse);
    });
  });
}
