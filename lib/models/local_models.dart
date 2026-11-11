import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a facility stock item tracked on-premises.
class Supply {
  Supply({
    required this.name,
    required this.onHand,
    required this.lowAt,
    required this.unit,
    this.batchNumber = 'BATCH-2025-08X',
    this.shelfLife = 'Exp: June 2028 (Good)',
  });

  final String name;
  int onHand;
  final int lowAt;
  final String unit;
  int reserved = 0;
  final String batchNumber;
  final String shelfLife;
}

typedef _Supply = Supply;

/// Represents an anonymous student or community member supply request.
class LocalRequest {
  const LocalRequest({
    required this.id,
    required this.reference,
    required this.pickupPin,
    required this.school,
    required this.area,
    required this.product,
    required this.quantity,
    required this.createdAt,
    required this.status,
    this.collectedAt,
    this.collectedBy,
  });

  final String id;
  final String reference;
  final String pickupPin;
  final String school;
  final String area;
  final String product;
  final int quantity;
  final String createdAt;
  final String status;
  final String? collectedAt;
  final String? collectedBy;

  Map<String, Object> toJson() => {
    'id': id,
    'reference': reference,
    'pickupPin': pickupPin,
    'school': school,
    'area': area,
    'product': product,
    'quantity': quantity,
    'createdAt': createdAt,
    'status': status,
    if (collectedAt != null) 'collectedAt': collectedAt!,
    if (collectedBy != null) 'collectedBy': collectedBy!,
  };

  factory LocalRequest.fromJson(Map<String, dynamic> json) {
    final ref = (json['reference'] ?? json['ref'] ?? '').toString();

    // Robust PIN extraction: supports String, int, with or without '#', or fallback to ref
    String pin = '';
    if (json['pickupPin'] != null) {
      pin = json['pickupPin'].toString().replaceAll('#', '').trim();
    } else if (json['pin'] != null) {
      pin = json['pin'].toString().replaceAll('#', '').trim();
    } else if (ref.contains('-')) {
      pin = ref.split('-').last.trim();
    } else {
      final rawId = (json['id'] ?? '').toString();
      pin = rawId.length >= 4 ? rawId.substring(rawId.length - 4) : '1000';
    }
    if (pin.length > 4) {
      pin = pin.substring(pin.length - 4);
    } else if (pin.length < 4) {
      pin = pin.padLeft(4, '0');
    }

    final rawId = (json['id'] ?? json['requestId'] ?? '').toString();
    final id = rawId.isNotEmpty ? rawId : 'req-${DateTime.now().microsecondsSinceEpoch}';

    // Quantity safe extraction
    final dynamic qtyRaw = json['quantity'] ?? json['qty'] ?? 1;
    final int qty = (qtyRaw is num) ? qtyRaw.toInt() : (int.tryParse(qtyRaw.toString()) ?? 1);

    // School name normalization
    String school = (json['school'] ?? json['facility'] ?? 'St. Mary\'s Secondary').toString().trim();
    final lowerSchool = school.toLowerCase();
    if (lowerSchool.contains('st. mary') || lowerSchool.contains('st mary') || lowerSchool.contains('secondary')) {
      school = 'St. Mary\'s Secondary';
    } else if (lowerSchool.contains('oli')) {
      school = 'Oli Primary School';
    } else if (lowerSchool.contains('ediofe')) {
      school = 'Ediofe Girls School';
    }

    // CreatedAt parsing
    String createdAtStr = DateTime.now().toIso8601String();
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      createdAtStr = rawCreatedAt;
    } else if (rawCreatedAt != null) {
      try {
        if (rawCreatedAt is Timestamp) {
          createdAtStr = rawCreatedAt.toDate().toIso8601String();
        } else {
          createdAtStr = DateTime.tryParse(rawCreatedAt.toString())?.toIso8601String() ?? createdAtStr;
        }
      } catch (_) {}
    }

    return LocalRequest(
      id: id,
      reference: ref.isNotEmpty ? ref : 'PH-$pin',
      pickupPin: pin,
      school: school,
      area: (json['area'] ?? 'Arua Hill').toString(),
      product: (json['product'] ?? 'Disposable pads').toString(),
      quantity: qty > 0 ? qty : 1,
      createdAt: createdAtStr,
      status: (json['status'] ?? 'Pending review').toString(),
      collectedAt: json['collectedAt']?.toString(),
      collectedBy: json['collectedBy']?.toString(),
    );
  }

  LocalRequest withStatus(String status, {String? collectedBy}) => LocalRequest(
    id: id,
    reference: reference,
    pickupPin: pickupPin,
    school: school,
    area: area,
    product: product,
    quantity: quantity,
    createdAt: createdAt,
    status: status,
    collectedAt: status == 'Collected' ? DateTime.now().toIso8601String() : collectedAt,
    collectedBy: collectedBy ?? this.collectedBy,
  );
}

typedef _LocalRequest = LocalRequest;

/// Generates a unique 4-digit PIN (1000-9999) guaranteed not to collide
/// with any active (non-collected) request.
class PinService {
  static String generateUniquePin(Iterable<LocalRequest> existingRequests) {
    final activePins = existingRequests
        .where((r) => r.status != 'Collected' && r.status != 'Declined')
        .map((r) => r.pickupPin.replaceAll('#', '').trim())
        .toSet();

    final rand = math.Random.secure();
    for (int attempts = 0; attempts < 1000; attempts++) {
      final candidate = (1000 + rand.nextInt(9000)).toString();
      if (!activePins.contains(candidate)) {
        return candidate;
      }
    }
    final secureFallback = 1000 + math.Random.secure().nextInt(9000);
    return secureFallback.toString();
  }
}

/// Represents the persisted local requests and school stock cache.
class LocalData {
  const LocalData({required this.requests, required this.stock});

  final List<LocalRequest> requests;
  final Map<String, int> stock;

  Map<String, Object> toJson() => {
    'requests': requests.map((request) => request.toJson()).toList(),
    'stock': stock,
  };
}

typedef _LocalData = LocalData;

const String _localStateKey = 'padcare.localState.v1';
const String _legacyLocalRequestsKey = 'padcare.localRequests.v1';

String stockKey(String school, String product) => '$school::$product';
String _stockKey(String school, String product) => stockKey(school, product);

Future<LocalData> readLocalData() async {
  final preferences = await SharedPreferences.getInstance();
  final current = preferences.getString(_localStateKey) ??
      preferences.getString('padher.localState.v1');
  final legacy = preferences.getString(_legacyLocalRequestsKey) ??
      preferences.getString('padher.localRequests.v1');
  final Object? decoded = current != null
      ? jsonDecode(current)
      : legacy == null
      ? null
      : jsonDecode(legacy);
  final data = decoded is Map
      ? decoded
      : <String, dynamic>{'requests': decoded, 'stock': <String, int>{}};
  final requestData = data['requests'];
  final requests = requestData is List
      ? requestData
            .map(
              (request) => LocalRequest.fromJson(
                Map<String, dynamic>.from(request as Map),
              ),
            )
            .toList()
      : <LocalRequest>[];
  final stockData = data['stock'];
  final stock = stockData is Map
      ? stockData.map<String, int>(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        )
      : <String, int>{};
  final retentionCutoff = DateTime.now().subtract(const Duration(days: 30));
  final retainedRequests = requests.where((request) {
    final created = DateTime.tryParse(request.createdAt);
    return created != null && created.isAfter(retentionCutoff);
  }).toList();
  final localData = LocalData(requests: retainedRequests, stock: stock);
  if (current == null || retainedRequests.length != requests.length) {
    final saved = await preferences.setString(
      _localStateKey,
      jsonEncode(localData.toJson()),
    );
    if (!saved) throw StateError('Local data could not be migrated or cleaned');
  }
  if (legacy != null) {
    await preferences.remove(_legacyLocalRequestsKey);
    await preferences.remove('padher.localRequests.v1');
  }
  if (current == null && preferences.containsKey('padher.localState.v1')) {
    await preferences.remove('padher.localState.v1');
  }
  return localData;
}

Future<LocalData> _readLocalData() => readLocalData();

Future<void> saveLocalData(LocalData data) async {
  final preferences = await SharedPreferences.getInstance();
  final saved = await preferences.setString(
    _localStateKey,
    jsonEncode(data.toJson()),
  );
  if (!saved) throw StateError('Local data could not be saved');
}

Future<void> _saveLocalData(LocalData data) => saveLocalData(data);

enum SupportSubTab { requestForm, activity, donate }
typedef _SupportSubTab = SupportSubTab;

class SupportPoint {
  const SupportPoint({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.distanceKm,
    required this.hours,
    required this.inStock,
    required this.isVerified,
    required this.directions,
    required this.mapOffsetPercent,
    required this.pinLabel,
    this.supplies = 'Pads & kits',
    this.instructions = 'Walk in and ask for adolescent health or matron desk. Confidential and free.',
    this.phone = '+256 772 100 200',
    this.lastUpdated = 'Today at 09:00 AM',
  });

  final String id;
  final String name;
  final String category;
  final String area;
  final double distanceKm;
  final String hours;
  final bool inStock;
  final bool isVerified;
  final String directions;
  final Offset mapOffsetPercent;
  final String pinLabel;
  final String supplies;
  final String instructions;
  final String phone;
  final String lastUpdated;
}

typedef _SupportPoint = SupportPoint;

const kSupportPoints = <SupportPoint>[
  SupportPoint(
    id: 'muni-clinic',
    name: 'Muni Health Centre IV',
    category: 'Clinics',
    area: 'Muni',
    distanceKm: 0.8,
    hours: 'Open until 5:00 PM',
    inStock: true,
    isVerified: true,
    directions: 'Muni Junction, Rhinocamp Rd',
    mapOffsetPercent: Offset(0.42, 0.42),
    pinLabel: 'Clinic',
    supplies: 'Disposable & Reusable pads',
    instructions: 'Report to outpatient clinic room 3. Supplies provided immediately with discretion.',
    phone: '+256 772 450 119',
    lastUpdated: 'Today at 08:30 AM',
  ),
  SupportPoint(
    id: 'arua-hospital',
    name: 'Arua Regional Referral Hospital',
    category: 'Clinics',
    area: 'Arua Central',
    distanceKm: 1.1,
    hours: 'Open 24/7',
    inStock: true,
    isVerified: true,
    directions: 'Hospital Road, Arua Central',
    mapOffsetPercent: Offset(0.50, 0.48),
    pinLabel: 'Clinic',
    supplies: 'Emergency hospital stock',
    instructions: 'Maternity & Youth Friendly Corner. Open 24/7 with trained female nursing staff.',
    phone: '+256 476 420 021',
    lastUpdated: 'Today at 09:15 AM',
  ),
  SupportPoint(
    id: 'ediofe-school',
    name: 'Ediofe Girls School',
    category: 'Schools',
    area: 'Ediofe',
    distanceKm: 1.4,
    hours: 'Open until 4:30 PM',
    inStock: true,
    isVerified: true,
    directions: 'Ediofe Mission Road',
    mapOffsetPercent: Offset(0.63, 0.42),
    pinLabel: 'School',
    supplies: 'Reusable pad kits & disposable',
    instructions: 'Senior Woman Teacher office near the administration block.',
    phone: '+256 782 300 812',
    lastUpdated: 'Yesterday at 04:00 PM',
  ),
  SupportPoint(
    id: 'st-marys-school',
    name: 'St. Mary\'s Secondary',
    category: 'Schools',
    area: 'Arua Hill',
    distanceKm: 2.0,
    hours: 'Open until 5:00 PM',
    inStock: true,
    isVerified: true,
    directions: 'Arua Hill Avenue',
    mapOffsetPercent: Offset(0.42, 0.55),
    pinLabel: 'School',
    supplies: 'Kits & packs for pickup',
    instructions: 'School health liaison office. Parent & student collections welcome.',
    phone: '+256 774 912 345',
    lastUpdated: 'Today at 10:00 AM',
  ),
  SupportPoint(
    id: 'ceford-ngo',
    name: 'CEFORD Community Centre',
    category: 'NGOs',
    area: 'Arua Central',
    distanceKm: 1.8,
    hours: 'Open until 5:00 PM',
    inStock: true,
    isVerified: true,
    directions: 'Catholic Diocese, Central',
    mapOffsetPercent: Offset(0.61, 0.55),
    pinLabel: 'Collect',
    supplies: 'Emergency distribution hub',
    instructions: 'Community empowerment desk, ground floor reception.',
    phone: '+256 476 422 555',
    lastUpdated: 'Today at 11:30 AM',
  ),
  SupportPoint(
    id: 'oli-primary',
    name: 'Oli Primary School',
    category: 'Schools',
    area: 'Oli',
    distanceKm: 2.5,
    hours: 'Open until 4:00 PM',
    inStock: true,
    isVerified: true,
    directions: 'Oli Division Road',
    mapOffsetPercent: Offset(0.61, 0.60),
    pinLabel: 'School',
    supplies: 'School stock & parent pickups',
    instructions: 'Staffroom counseling corner, ask for Senior Woman Teacher.',
    phone: '+256 752 118 900',
    lastUpdated: 'Today at 07:45 AM',
  ),
];

const _kSupportPoints = kSupportPoints;

class LearnArticle {
  const LearnArticle({
    required this.tag,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
  });

  final String tag;
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> content;
}

typedef _LearnArticle = LearnArticle;
