import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Predefined user roles in PadCare.
class UserRole {
  static const String teacher = 'teacher';
  static const String schoolAdmin = 'school_admin';
  static const String sponsor = 'sponsor';
  static const String superAdmin = 'super_admin';
  static const String parent = 'parent';

  static const List<String> allRoles = [
    teacher,
    schoolAdmin,
    sponsor,
    superAdmin,
    parent,
  ];

  static String displayName(String role) {
    switch (role) {
      case teacher:
        return 'Teacher';
      case schoolAdmin:
        return 'School Matron / Administrator';
      case sponsor:
        return 'Sponsor / Donor';
      case superAdmin:
        return 'Platform Administrator';
      case parent:
      default:
        return 'Parent / Community Member';
    }
  }
}

/// Comprehensive User Profile Model for PadCare
class UserProfileModel {
  final String uid;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? photoUrl;
  final String role;
  final String? schoolId;
  final String? schoolName;
  final String accountStatus; // 'active' | 'pending_approval' | 'suspended'
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final Map<String, bool> notificationPreferences;

  const UserProfileModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.photoUrl,
    required this.role,
    this.schoolId,
    this.schoolName,
    this.accountStatus = 'active',
    required this.createdAt,
    this.lastLoginAt,
    this.notificationPreferences = const {
      'requests': true,
      'inventory': true,
      'announcements': true,
    },
  });

  bool get isApproved => accountStatus == 'active';
  bool get isTeacher => role == UserRole.teacher;
  bool get isSchoolAdmin => role == UserRole.schoolAdmin;
  bool get isSponsor => role == UserRole.sponsor;
  bool get isSuperAdmin => role == UserRole.superAdmin;

  UserProfileModel copyWith({
    String? fullName,
    String? phoneNumber,
    String? photoUrl,
    String? role,
    String? schoolId,
    String? schoolName,
    String? accountStatus,
    DateTime? lastLoginAt,
    Map<String, bool>? notificationPreferences,
  }) {
    return UserProfileModel(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      accountStatus: accountStatus ?? this.accountStatus,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'fullName': fullName,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'role': role,
    if (schoolId != null) 'schoolId': schoolId,
    if (schoolName != null) 'schoolName': schoolName,
    'accountStatus': accountStatus,
    'createdAt': createdAt.toIso8601String(),
    if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
    'notificationPreferences': notificationPreferences,
  };

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final rawPrefs = json['notificationPreferences'];
    final Map<String, bool> prefs = (rawPrefs is Map)
        ? rawPrefs.map((k, v) => MapEntry(k.toString(), v == true))
        : const {'requests': true, 'inventory': true, 'announcements': true};

    return UserProfileModel(
      uid: (json['uid'] ?? json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['displayName'] ?? json['name'] ?? '').toString(),
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      role: (json['role'] ?? UserRole.parent).toString(),
      schoolId: (json['schoolId'] ?? json['school']) as String?,
      schoolName: (json['schoolName'] ?? json['school']) as String?,
      accountStatus: (json['accountStatus'] ?? json['status'] ?? 'active').toString(),
      createdAt: parseDate(json['createdAt']),
      lastLoginAt: json['lastLoginAt'] != null ? parseDate(json['lastLoginAt']) : null,
      notificationPreferences: prefs,
    );
  }
}
