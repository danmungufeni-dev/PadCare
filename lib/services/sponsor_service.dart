import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Donation record in Firestore `donations/{donationId}`
class DonationModel {
  final String donationId;
  final String sponsorUid;
  final String sponsorName;
  final int amountUGX;
  final int kitsFunded;
  final String? schoolId;
  final String? schoolName;
  final String paymentMethod; // 'MoMo' | 'Airtel' | 'Card'
  final String paymentStatus; // 'completed' | 'pending' | 'failed'
  final String transactionReference;
  final String? receiptNumber;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const DonationModel({
    required this.donationId,
    required this.sponsorUid,
    this.sponsorName = 'Anonymous Sponsor',
    required this.amountUGX,
    required this.kitsFunded,
    this.schoolId,
    this.schoolName,
    this.paymentMethod = 'MoMo',
    this.paymentStatus = 'completed',
    required this.transactionReference,
    this.receiptNumber,
    this.verifiedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'donationId': donationId,
    'id': donationId,
    'sponsorUid': sponsorUid,
    'donorName': sponsorName,
    'amount': amountUGX,
    'currency': 'UGX',
    'kitsFunded': kitsFunded,
    if (schoolId != null) 'schoolId': schoolId,
    if (schoolName != null) 'school': schoolName,
    'paymentMethod': paymentMethod,
    'status': paymentStatus,
    'reference': transactionReference,
    if (receiptNumber != null) 'receiptNumber': receiptNumber,
    if (verifiedAt != null) 'verifiedAt': verifiedAt!.toIso8601String(),
    'timestamp': createdAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    return DonationModel(
      donationId: (json['donationId'] ?? json['id'] ?? '').toString(),
      sponsorUid: (json['sponsorUid'] ?? json['uid'] ?? '').toString(),
      sponsorName: (json['donorName'] ?? json['sponsorName'] ?? 'Anonymous Sponsor').toString(),
      amountUGX: (json['amount'] is num) ? (json['amount'] as num).toInt() : 0,
      kitsFunded: (json['kitsFunded'] is num) ? (json['kitsFunded'] as num).toInt() : 0,
      schoolId: json['schoolId'] as String?,
      schoolName: json['school'] as String?,
      paymentMethod: (json['paymentMethod'] ?? 'MoMo').toString(),
      paymentStatus: (json['status'] ?? 'completed').toString(),
      transactionReference: (json['reference'] ?? json['transactionReference'] ?? '').toString(),
      receiptNumber: json['receiptNumber'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? (DateTime.tryParse(json['verifiedAt'].toString()))
          : null,
      createdAt: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Campaign model for school dignity kit funding
class CampaignModel {
  final String campaignId;
  final String title;
  final String description;
  final int targetKits;
  final int fundedKits;
  final int targetUGX;
  final int raisedUGX;
  final String status;

  const CampaignModel({
    required this.campaignId,
    required this.title,
    required this.description,
    required this.targetKits,
    this.fundedKits = 0,
    required this.targetUGX,
    this.raisedUGX = 0,
    this.status = 'active',
  });

  double get progress => targetKits > 0 ? (fundedKits / targetKits).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'campaignId': campaignId,
    'title': title,
    'description': description,
    'targetKits': targetKits,
    'fundedKits': fundedKits,
    'targetUGX': targetUGX,
    'raisedUGX': raisedUGX,
    'status': status,
  };

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      campaignId: (json['campaignId'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Dignity Kits Campaign').toString(),
      description: (json['description'] ?? '').toString(),
      targetKits: (json['targetKits'] is num) ? (json['targetKits'] as num).toInt() : 100,
      fundedKits: (json['fundedKits'] is num) ? (json['fundedKits'] as num).toInt() : 0,
      targetUGX: (json['targetUGX'] is num) ? (json['targetUGX'] as num).toInt() : 5000000,
      raisedUGX: (json['raisedUGX'] is num) ? (json['raisedUGX'] as num).toInt() : 0,
      status: (json['status'] ?? 'active').toString(),
    );
  }
}

/// Service managing sponsors, donations, and school campaigns.
class SponsorService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  /// Records a verified donation transaction in Firestore `donations/{donationId}`.
  static Future<void> recordDonation(DonationModel donation) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('donations').doc(donation.donationId).set({
        ...donation.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('SponsorService recordDonation error: $e');
    }
  }

  /// Streams donations for a specific sponsor.
  static Stream<List<DonationModel>> streamDonationsForSponsor(String sponsorUid) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('donations')
        .where('sponsorUid', isEqualTo: sponsorUid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DonationModel.fromJson(doc.data())).toList())
        .handleError((e) {
          debugPrint('streamDonationsForSponsor error: $e');
          return <DonationModel>[];
        });
  }

  /// Streams active school campaigns across Arua City.
  static Stream<List<CampaignModel>> streamActiveCampaigns() {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return Stream.value([
        const CampaignModel(
          campaignId: 'arua-term1-kits',
          title: 'Term 1 Dignity Kits for Secondary Schools',
          description: 'Funding 500 reusable sanitary pad kits for girls in Arua City.',
          targetKits: 500,
          fundedKits: 280,
          targetUGX: 25000000,
          raisedUGX: 14000000,
        ),
      ]);
    }
    return _db!
        .collection('campaigns')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CampaignModel.fromJson(doc.data())).toList())
        .handleError((e) {
          debugPrint('streamActiveCampaigns error: $e');
          return <CampaignModel>[];
        });
  }
}
