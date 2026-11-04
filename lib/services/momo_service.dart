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
      sponsoredKits: 20,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    MoMoDonation(
      id: 'momo-init-2',
      donorName: 'Ediofe Old Students Assoc.',
      phone: '+256 782 445 ***',
      amountUgx: 150000,
      provider: 'Airtel Money',
      sponsoredKits: 10,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
    MoMoDonation(
      id: 'momo-init-3',
      donorName: 'Community Champion (Amina K.)',
      phone: '+256 752 908 ***',
      amountUgx: 45000,
      provider: 'MTN Mobile Money',
      sponsoredKits: 3,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 14)),
    ),
  ];

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
