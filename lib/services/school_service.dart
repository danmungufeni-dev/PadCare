import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

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
    'oli-primary-school': SchoolModel(
      schoolId: 'oli-primary-school',
      name: 'Oli Primary School',
      district: 'Arua',
      subCounty: 'Oli',
      createdAt: DateTime.now(),
    ),
    'ediofe-girls-school': SchoolModel(
      schoolId: 'ediofe-girls-school',
      name: 'Ediofe Girls School',
      district: 'Arua',
      subCounty: 'Ediofe',
      createdAt: DateTime.now(),
    ),
  };

  /// Registers or updates a school in Firestore `schools/{schoolId}`.
  static Future<void> saveSchool(SchoolModel school) async {
    _memorySchools[school.schoolId] = school;
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
