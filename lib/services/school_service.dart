import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'offline_queue_service.dart';

/// Represents a participating school facility in PadCare.
class SchoolModel {
  final String schoolId;
  final String name;
  final String registrationNumber;
  final String district;
  final String subCounty;
  final String contactPhone;
  final String contactEmail;
  final String? logoUrl;
  final String status; // 'active' | 'pending' | 'suspended'
  final List<String> assignedStaffUids;
  final DateTime createdAt;

  const SchoolModel({
    required this.schoolId,
    required this.name,
    this.registrationNumber = 'UNREGISTERED',
    this.district = 'Arua',
    this.subCounty = 'Arua Hill',
    this.contactPhone = '+256700000000',
    this.contactEmail = 'school@padcare.org',
    this.logoUrl,
    this.status = 'active',
    this.assignedStaffUids = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'schoolId': schoolId,
    'name': name,
    'registrationNumber': registrationNumber,
    'district': district,
    'subCounty': subCounty,
    'contactPhone': contactPhone,
    'contactEmail': contactEmail,
    if (logoUrl != null) 'logoUrl': logoUrl,
    'status': status,
    'assignedStaffUids': assignedStaffUids,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      schoolId: (json['schoolId'] ?? json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? 'Unnamed School').toString(),
      registrationNumber: (json['registrationNumber'] ?? 'UNREGISTERED').toString(),
      district: (json['district'] ?? 'Arua').toString(),
      subCounty: (json['subCounty'] ?? 'Arua Hill').toString(),
      contactPhone: (json['contactPhone'] ?? '+256700000000').toString(),
      contactEmail: (json['contactEmail'] ?? 'school@padcare.org').toString(),
      logoUrl: json['logoUrl'] as String?,
      status: (json['status'] ?? 'active').toString(),
      assignedStaffUids: (json['assignedStaffUids'] is List)
          ? List<String>.from(json['assignedStaffUids'] as List)
          : const [],
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Service managing school facilities, status, and staff associations.
class SchoolService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  static final Map<String, SchoolModel> _memorySchools = {
    'st-marys-secondary': SchoolModel(
      schoolId: 'st-marys-secondary',
      name: "St. Mary's Secondary",
      district: 'Arua',
      subCounty: 'Arua Hill',
      createdAt: DateTime.now(),
    ),
    'ediofe-girls-school': SchoolModel(
      schoolId: 'ediofe-girls-school',
      name: 'Ediofe Girls School',
      district: 'Arua',
      subCounty: 'Ediofe',
      createdAt: DateTime.now(),
    ),
    'oli-primary-school': SchoolModel(
      schoolId: 'oli-primary-school',
      name: 'Oli Primary School',
      district: 'Arua',
      subCounty: 'Oli',
      createdAt: DateTime.now(),
    ),
    'arua-public-primary': SchoolModel(
      schoolId: 'arua-public-primary',
      name: 'Arua Public Primary',
      district: 'Arua',
      subCounty: 'Arua Hill',
      createdAt: DateTime.now(),
    ),
    'mvara-secondary': SchoolModel(
      schoolId: 'mvara-secondary',
      name: 'Mvara Secondary',
      district: 'Arua',
      subCounty: 'Arua Hill',
      createdAt: DateTime.now(),
    ),
    'muni-girls-secondary': SchoolModel(
      schoolId: 'muni-girls-secondary',
      name: 'Muni Girls Secondary',
      district: 'Arua',
      subCounty: 'Ayivu',
      createdAt: DateTime.now(),
    ),
    'logiri-girls-secondary': SchoolModel(
      schoolId: 'logiri-girls-secondary',
      name: 'Logiri Girls Secondary',
      district: 'Arua',
      subCounty: 'Logiri',
      createdAt: DateTime.now(),
    ),
    'offaka-secondary': SchoolModel(
      schoolId: 'offaka-secondary',
      name: 'Offaka Secondary',
      district: 'Arua',
      subCounty: 'Offaka',
      createdAt: DateTime.now(),
    ),
  };

  /// Generates a clean URL/doc slug from a school name.
  static String generateSchoolId(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'school-${DateTime.now().millisecondsSinceEpoch}' : slug;
  }

  /// Returns sorted list of known school names from memory cache.
  static List<String> get cachedSchoolNames {
    final set = <String>{};
    for (final s in _memorySchools.values) {
      set.add(s.name);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Fetches schools from Firestore `schools` collection and updates memory cache.
  static Future<List<String>> fetchSchoolNames() async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return cachedSchoolNames;
    }
    try {
      final snap = await _db!.collection('schools').get();
      for (final doc in snap.docs) {
        final school = SchoolModel.fromJson(doc.data());
        _memorySchools[school.schoolId] = school;
        _memorySchools[school.name] = school;
      }
    } catch (e) {
      debugPrint('SchoolService fetchSchoolNames error: $e');
    }
    return cachedSchoolNames;
  }

  /// Registers or updates a school in Firestore `schools/{schoolId}` and offline queue.
  static Future<void> saveSchool(SchoolModel school, {bool enqueueOffline = true}) async {
    _memorySchools[school.schoolId] = school;
    _memorySchools[school.name] = school;

    if (enqueueOffline) {
      unawaited(
        OfflineQueueService.enqueue(
          type: 'save_school',
          payload: school.toJson(),
        ),
      );
    }

    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('schools').doc(school.schoolId).set(
        {
          ...school.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('SchoolService saveSchool error: $e');
    }
  }

  /// Fetches a school by its ID or Name.
  static Future<SchoolModel?> getSchool(String schoolIdOrName) async {
    if (_memorySchools.containsKey(schoolIdOrName)) {
      return _memorySchools[schoolIdOrName];
    }
    if (!FirebaseService.isFirebaseAvailable || _db == null) return null;
    try {
      final doc = await _db!.collection('schools').doc(schoolIdOrName).get();
      if (doc.exists && doc.data() != null) {
        return SchoolModel.fromJson(doc.data()!);
      }
      final query = await _db!
          .collection('schools')
          .where('name', isEqualTo: schoolIdOrName)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return SchoolModel.fromJson(query.docs.first.data());
      }
    } catch (e) {
      debugPrint('SchoolService getSchool error: $e');
    }
    return null;
  }

  /// Streams list of all participating schools.
  static Stream<List<SchoolModel>> streamSchools() {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return Stream.value(_memorySchools.values.toList());
    }
    return _db!.collection('schools').snapshots().map(
      (snap) => snap.docs.map((doc) => SchoolModel.fromJson(doc.data())).toList(),
    ).handleError((e) {
      debugPrint('streamSchools error: $e');
      return _memorySchools.values.toList();
    });
  }

  /// Updates status of a school ('active' | 'suspended' | 'pending').
  static Future<void> updateSchoolStatus(String schoolId, String status) async {
    final existing = _memorySchools[schoolId];
    if (existing != null) {
      _memorySchools[schoolId] = SchoolModel(
        schoolId: existing.schoolId,
        name: existing.name,
        registrationNumber: existing.registrationNumber,
        district: existing.district,
        subCounty: existing.subCounty,
        status: status,
        assignedStaffUids: existing.assignedStaffUids,
        createdAt: existing.createdAt,
      );
    }
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('schools').doc(schoolId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('updateSchoolStatus error: $e');
    }
  }
}
