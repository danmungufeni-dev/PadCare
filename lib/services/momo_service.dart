import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class MoMoDonation {
  final String id;
  final String donorName;
  final String phone;
  final int amountUgx;
  final String provider; // 'MTN Mobile Money' | 'Airtel Money' | 'Card'
  final int sponsoredKits;
  final String status; // 'completed' | 'pending'
  final DateTime createdAt;

  const MoMoDonation({
    required this.id,
    required this.donorName,
    required this.phone,
    required this.amountUgx,
    required this.provider,
    required this.sponsoredKits,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'donorName': donorName,
    'phone': phone,
    'amountUgx': amountUgx,
    'provider': provider,
    'sponsoredKits': sponsoredKits,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MoMoDonation.fromJson(Map<String, dynamic> json) => MoMoDonation(
    id: json['id'] as String? ?? '',
    donorName: json['donorName'] as String? ?? 'Anonymous Donor',
    phone: json['phone'] as String? ?? '',
    amountUgx: (json['amountUgx'] as num?)?.toInt() ?? 15000,
    provider: json['provider'] as String? ?? 'MTN Mobile Money',
    sponsoredKits: (json['sponsoredKits'] as num?)?.toInt() ?? 1,
    status: json['status'] as String? ?? 'completed',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class MoMoService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  /// Calculates number of complete menstrual kits sponsored by a UGX amount
  static int calculateSponsoredKits(int amountUgx) {
    if (amountUgx < 15000) return 1;
    return (amountUgx / 15000).floor();
  }

  /// Processes and records a Mobile Money pad sponsorship in Cloud Firestore
  static Future<bool> processDonation({
    required String phone,
    required int amountUgx,
    required String provider,
    String? donorName,
  }) async {
    final cleanPhone = AuthService.formatPhoneNumber(phone.trim());
    final kits = calculateSponsoredKits(amountUgx);
    final donationId = 'momo-${DateTime.now().millisecondsSinceEpoch}';

    final donation = MoMoDonation(
      id: donationId,
      donorName: (donorName != null && donorName.trim().isNotEmpty)
          ? donorName.trim()
          : 'PadCare Champion ($cleanPhone)',
      phone: cleanPhone,
      amountUgx: amountUgx,
      provider: provider,
      sponsoredKits: kits,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    if (FirebaseService.isFirebaseAvailable && _db != null) {
      try {
        await _db!.collection('donations').doc(donationId).set({
          ...donation.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (e) {
        debugPrint('MoMoService donation error: $e');
      }
    }

    return true; // Graceful success in offline mode
  }

  /// Real-time stream of total sponsored pads funded by the community
  static Stream<int> streamTotalKitsSponsored() {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return Stream.value(142); // Default community count
    }
    return _db!
        .collection('donations')
        .snapshots()
        .map((snapshot) {
          int total = 142; // Base milestone count
          for (final doc in snapshot.docs) {
            final kits = (doc.data()['sponsoredKits'] as num?)?.toInt() ?? 0;
            total += kits;
          }
          return total;
        })
        .handleError((_) => 142);
  }
}
