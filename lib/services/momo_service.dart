import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'offline_queue_service.dart';

/// PadCare Mobile Money & Community Sponsorship Service.
/// 
/// Note: Currently configured for Community Sponsorship Simulation & Free Tier Sandbox.
/// Records sponsor donations, updates live community impact counters, and logs transactions in Firestore.
/// Architecture is pre-structured for production MTN MoMo and Airtel Money IPN webhook callbacks
/// once production merchant credentials and webhook servers are provisioned.
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
    'donationId': id,
    'donorName': donorName,
    'phone': phone,
    'amount': amountUgx,
    'amountUgx': amountUgx,
    'currency': 'UGX',
    'reference': id,
    'provider': provider,
    'sponsoredKits': sponsoredKits,
    'kitsFunded': sponsoredKits,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    if (AuthService.currentUser?.uid != null) 'sponsorUid': AuthService.currentUser!.uid,
    if (AuthService.currentUser?.uid != null) 'uid': AuthService.currentUser!.uid,
  };

  factory MoMoDonation.fromJson(Map<String, dynamic> json) => MoMoDonation(
    id: json['id'] as String? ?? json['donationId'] as String? ?? '',
    donorName: json['donorName'] as String? ?? json['sponsorName'] as String? ?? 'Anonymous Donor',
    phone: json['phone'] as String? ?? '',
    amountUgx: (json['amountUgx'] as num?)?.toInt() ?? (json['amount'] as num?)?.toInt() ?? 3000,
    provider: json['provider'] as String? ?? json['paymentMethod'] as String? ?? 'MTN Mobile Money',
    sponsoredKits: (json['sponsoredKits'] as num?)?.toInt() ?? (json['kitsFunded'] as num?)?.toInt() ?? 1,
    status: json['status'] as String? ?? 'completed',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class MoMoImpactSummary {
  final int totalAmountUgx;
  final int totalKitsSponsored;
  final int schoolsBenefited;
  final List<MoMoDonation> recentDonations;

  const MoMoImpactSummary({
    required this.totalAmountUgx,
    required this.totalKitsSponsored,
    required this.schoolsBenefited,
    required this.recentDonations,
  });
}

class MoMoService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  static final List<MoMoDonation> _initialDonations = [
    MoMoDonation(
      id: 'momo-init-1',
      donorName: 'Arua Rotary Club',
      phone: '+256 772 110 ***',
      amountUgx: 300000,
      provider: 'MTN Mobile Money',
      sponsoredKits: 100,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    MoMoDonation(
      id: 'momo-init-2',
      donorName: 'Ediofe Old Students Assoc.',
      phone: '+256 782 445 ***',
      amountUgx: 150000,
      provider: 'Airtel Money',
      sponsoredKits: 50,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
    MoMoDonation(
      id: 'momo-init-3',
      donorName: 'Community Champion (Amina K.)',
      phone: '+256 752 908 ***',
      amountUgx: 45000,
      provider: 'MTN Mobile Money',
      sponsoredKits: 15,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 14)),
    ),
  ];

  /// Calculates number of complete menstrual kits sponsored by a UGX amount (UGX 3,000 per kit)
  static int calculateSponsoredKits(int amountUgx) {
    if (amountUgx < 3000) return 1;
    return (amountUgx / 3000).floor();
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
          : 'PadCare Supporter ($cleanPhone)',
      phone: cleanPhone,
      amountUgx: amountUgx,
      provider: provider,
      sponsoredKits: kits,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    _initialDonations.insert(0, donation);

    if (FirebaseService.isFirebaseAvailable && _db != null) {
      try {
        await _db!.collection('donations').doc(donationId).set({
          ...donation.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (e) {
        debugPrint('MoMoService donation error: $e');
        await OfflineQueueService.enqueue(
          type: 'record_donation',
          payload: donation.toJson(),
        );
        return true;
      }
    } else {
      await OfflineQueueService.enqueue(
        type: 'record_donation',
        payload: donation.toJson(),
      );
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

  /// Real-time stream of comprehensive community sponsorship metrics
  static Stream<MoMoImpactSummary> streamImpactSummary() {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return Stream.value(
        MoMoImpactSummary(
          totalAmountUgx: 2130000,
          totalKitsSponsored: 142,
          schoolsBenefited: 4,
          recentDonations: _initialDonations,
        ),
      );
    }
    return _db!
        .collection('donations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          int totalUgx = 2130000;
          int totalKits = 142;
          final List<MoMoDonation> donations = [];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final d = MoMoDonation.fromJson(data);
            donations.add(d);
            totalUgx += d.amountUgx;
            totalKits += d.sponsoredKits;
          }

          if (donations.isEmpty) {
            donations.addAll(_initialDonations);
          }

          return MoMoImpactSummary(
            totalAmountUgx: totalUgx,
            totalKitsSponsored: totalKits,
            schoolsBenefited: 4,
            recentDonations: donations.take(10).toList(),
          );
        })
        .handleError((_) => MoMoImpactSummary(
              totalAmountUgx: 2130000,
              totalKitsSponsored: 142,
              schoolsBenefited: 4,
              recentDonations: _initialDonations,
            ));
  }
}
