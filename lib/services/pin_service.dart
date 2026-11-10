import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Secure PIN record stored in Firestore `pin_records/{pin}`
class PinRecordModel {
  final String pin;
  final String requestId;
  final String reference;
  final String schoolId;
  final String productId;
  final int quantity;
  final String status; // 'active' | 'redeemed' | 'expired' | 'revoked'
  final int failedAttempts;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? redeemedAt;

  const PinRecordModel({
    required this.pin,
    required this.requestId,
    required this.reference,
    required this.schoolId,
    required this.productId,
    required this.quantity,
    this.status = 'active',
    this.failedAttempts = 0,
    required this.expiresAt,
    required this.createdAt,
    this.redeemedAt,
  });

  bool get isActive => status == 'active' && DateTime.now().isBefore(expiresAt);

  Map<String, dynamic> toJson() => {
    'pin': pin,
    'requestId': requestId,
    'reference': reference,
    'schoolId': schoolId,
    'productId': productId,
    'quantity': quantity,
    'status': status,
    'failedAttempts': failedAttempts,
    'expiresAt': expiresAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    if (redeemedAt != null) 'redeemedAt': redeemedAt!.toIso8601String(),
  };

  factory PinRecordModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return PinRecordModel(
      pin: (json['pin'] ?? '').toString().replaceAll('#', '').trim(),
      requestId: (json['requestId'] ?? '').toString(),
      reference: (json['reference'] ?? 'PH-${json['pin']}').toString(),
      schoolId: (json['schoolId'] ?? '').toString(),
      productId: (json['productId'] ?? 'disposable-pads').toString(),
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1,
      status: (json['status'] ?? 'active').toString(),
      failedAttempts: (json['failedAttempts'] is num) ? (json['failedAttempts'] as num).toInt() : 0,
      expiresAt: parseDate(json['expiresAt']),
      createdAt: parseDate(json['createdAt']),
      redeemedAt: json['redeemedAt'] != null ? parseDate(json['redeemedAt']) : null,
    );
  }
}

/// Secure PIN Generator and Verification Service with rate-limiting support.
class SecurePinService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  /// Generates a cryptographically sound random 4-digit numeric PIN ('1000' - '9999').
  static String generatePin() {
    final rand = math.Random.secure();
    final num = 1000 + rand.nextInt(9000);
    return num.toString();
  }

  /// Saves a newly generated PIN record in Firestore `pin_records/{pin}`.
  static Future<void> registerPin(PinRecordModel record) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('pin_records').doc(record.pin).set({
        ...record.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('SecurePinService registerPin error: $e');
    }
  }

  /// Verifies a PIN against Firestore `pin_records` with rate-limiting checks.
  static Future<Map<String, dynamic>> verifyPin({
    required String rawPin,
    required String schoolFacility,
  }) async {
    final cleanPin = rawPin.replaceAll('#', '').trim();
    if (cleanPin.isEmpty || cleanPin.length != 4) {
      return {'valid': false, 'error': 'PIN must be exactly 4 digits.'};
    }

    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return {'valid': true, 'offline': true, 'pin': cleanPin};
    }

    try {
      final doc = await _db!.collection('pin_records').doc(cleanPin).get();
      if (!doc.exists || doc.data() == null) {
        return {'valid': false, 'error': 'PIN #$cleanPin does not exist.'};
      }

      final record = PinRecordModel.fromJson(doc.data()!);

      // Check brute-force attempts
      if (record.failedAttempts >= 5) {
        return {
          'valid': false,
          'error': 'PIN #$cleanPin is locked due to too many failed attempts.',
        };
      }

      // Check status
      if (record.status == 'redeemed') {
        return {
          'valid': false,
          'error': 'PIN #$cleanPin has already been redeemed and dispensed.',
        };
      }

      if (record.status == 'revoked' || record.status == 'expired') {
        return {
          'valid': false,
          'error': 'PIN #$cleanPin is no longer active (${record.status}).',
        };
      }

      // School match
      if (record.schoolId != schoolFacility &&
          !schoolFacility.toLowerCase().contains(record.schoolId.toLowerCase())) {
        return {
          'valid': false,
          'error': 'PIN #$cleanPin belongs to another school (${record.schoolId}).',
        };
      }

      return {'valid': true, 'record': record};
    } catch (e) {
      return {'valid': false, 'error': 'Verification error: $e'};
    }
  }

  /// Increments failed attempts counter for a PIN.
  static Future<void> incrementFailedAttempts(String pin) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('pin_records').doc(pin).update({
        'failedAttempts': FieldValue.increment(1),
        'lastAttemptAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
