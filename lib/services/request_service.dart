import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Represents sanitary pad request in PadCare.
class RequestModel {
  final String requestId;
  final String reference;
  final String teacherUid;
  final String teacherName;
  final String schoolId;
  final String schoolName;
  final String productId;
  final String productName;
  final int quantity;
  final String pickupPin;
  final String status; // 'Pending' | 'Approved' | 'Rejected' | 'Ready for collection' | 'Collected' | 'Cancelled'
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? collectedAt;
  final String? collectedBy;

  const RequestModel({
    required this.requestId,
    required this.reference,
    required this.teacherUid,
    this.teacherName = 'Authorized Teacher',
    required this.schoolId,
    required this.schoolName,
    this.productId = 'disposable-pads',
    required this.productName,
    required this.quantity,
    required this.pickupPin,
    this.status = 'Pending',
    required this.createdAt,
    this.approvedAt,
    this.collectedAt,
    this.collectedBy,
  });

  bool get isCollected => status == 'Collected';
  bool get isApproved => status == 'Approved';
  bool get isReady => status == 'Ready for collection';
  bool get isCancelled => status == 'Cancelled';

  RequestModel copyWith({
    String? status,
    DateTime? approvedAt,
    DateTime? collectedAt,
    String? collectedBy,
  }) {
    return RequestModel(
      requestId: requestId,
      reference: reference,
      teacherUid: teacherUid,
      teacherName: teacherName,
      schoolId: schoolId,
      schoolName: schoolName,
      productId: productId,
      productName: productName,
      quantity: quantity,
      pickupPin: pickupPin,
      status: status ?? this.status,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      collectedAt: collectedAt ?? this.collectedAt,
      collectedBy: collectedBy ?? this.collectedBy,
    );
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'id': requestId,
    'reference': reference,
    'teacherUid': teacherUid,
    'teacherName': teacherName,
    'schoolId': schoolId,
    'school': schoolName,
    'productId': productId,
    'product': productName,
    'quantity': quantity,
    'pickupPin': pickupPin,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    if (collectedAt != null) 'collectedAt': collectedAt!.toIso8601String(),
    if (collectedBy != null) 'collectedBy': collectedBy,
  };

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final rawPin = (json['pickupPin'] ?? json['pin'] ?? '').toString().replaceAll('#', '').trim();
    final cleanPin = rawPin.isNotEmpty ? rawPin : '1000';
    final ref = (json['reference'] ?? json['ref'] ?? 'PH-$cleanPin').toString();

    return RequestModel(
      requestId: (json['requestId'] ?? json['id'] ?? '').toString(),
      reference: ref,
      teacherUid: (json['teacherUid'] ?? 'teacher-uid').toString(),
      teacherName: (json['teacherName'] ?? 'Teacher').toString(),
      schoolId: (json['schoolId'] ?? json['school'] ?? '').toString(),
      schoolName: (json['school'] ?? json['schoolName'] ?? "St. Mary's Secondary").toString(),
      productId: (json['productId'] ?? 'disposable-pads').toString(),
      productName: (json['product'] ?? json['productName'] ?? 'Disposable pads').toString(),
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : (int.tryParse(json['quantity']?.toString() ?? '1') ?? 1),
      pickupPin: cleanPin,
      status: (json['status'] ?? 'Pending').toString(),
      createdAt: parseDate(json['createdAt']),
      approvedAt: json['approvedAt'] != null ? parseDate(json['approvedAt']) : null,
      collectedAt: json['collectedAt'] != null ? parseDate(json['collectedAt']) : null,
      collectedBy: json['collectedBy'] as String?,
    );
  }
}

/// Request management service for sanitary pads.
class RequestService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  /// Saves or creates a new request in Firestore `requests/{requestId}`.
  static Future<void> createRequest(RequestModel request) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('requests').doc(request.requestId).set({
        ...request.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('RequestService createRequest error: $e');
    }
  }

  /// Streams active requests for a specific school.
  static Stream<List<RequestModel>> streamRequestsForSchool(String schoolNameOrId) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('requests')
        .where('school', isEqualTo: schoolNameOrId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RequestModel.fromJson(doc.data())).toList())
        .handleError((e) {
          debugPrint('streamRequestsForSchool error: $e');
          return <RequestModel>[];
        });
  }

  /// Streams requests created by a specific teacher.
  static Stream<List<RequestModel>> streamRequestsForTeacher(String teacherUid) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('requests')
        .where('teacherUid', isEqualTo: teacherUid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RequestModel.fromJson(doc.data())).toList())
        .handleError((e) {
          debugPrint('streamRequestsForTeacher error: $e');
          return <RequestModel>[];
        });
  }

  /// Updates status of a request with audit timestamps.
  static Future<void> updateStatus(String requestId, String status, {String? staffIdentifier}) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      final Map<String, dynamic> updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status == 'Approved') {
        updateData['approvedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'Collected') {
        updateData['collectedAt'] = FieldValue.serverTimestamp();
        if (staffIdentifier != null) updateData['collectedBy'] = staffIdentifier;
      }
      await _db!.collection('requests').doc(requestId).update(updateData);
    } catch (e) {
      debugPrint('RequestService updateStatus error: $e');
    }
  }
}
