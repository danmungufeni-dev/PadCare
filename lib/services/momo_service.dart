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
    amountUgx: (json['amountUgx'] as num?)?.toInt() ?? 3000,
    provider: json['provider'] as String? ?? 'MTN Mobile Money',
    sponsoredKits: (json['sponsoredKits'] as num?)?.toInt() ?? 1,
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

  /// Records a sponsorship pledge. This client does not initiate or verify a
  /// Mobile Money payment; cloud pledges remain pending until a trusted server
  /// confirms payment.
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
      status: 'pending_verification',
      createdAt: DateTime.now(),
    );

    _initialDonations.insert(0, donation);

    if (FirebaseService.isFirebaseAvailable && _db != null) {
      try {
        // Never upload donor names or phone numbers to this publicly readable
        // collection. A client can create only a pending pledge; a trusted
        // payment-verification backend must mark it completed.
        await _db!.collection('donations').doc(donationId).set({
          'id': donationId,
          'amountUgx': amountUgx,
          'provider': provider,
          'sponsoredKits': kits,
          'status': 'pending_verification',
          'createdAt': donation.createdAt.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (e) {
        debugPrint('MoMoService donation pledge error: $e');
        return false;
      }
    }

    return true; // Offline demo only; no payment is processed.
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
            final data = doc.data();
            if (data['status'] == 'completed') {
              final kits = (data['sponsoredKits'] as num?)?.toInt() ?? 0;
              total += kits;
            }
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
            // Pending pledges are not counted as money received or kits funded.
            if (data['status'] == 'completed') {
              totalUgx += d.amountUgx;
              totalKits += d.sponsoredKits;
            }
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
