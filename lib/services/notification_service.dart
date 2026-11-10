import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Notification model in Firestore `notifications/{id}`
class NotificationItemModel {
  final String id;
  final String recipientUid;
  final String? schoolId;
  final String title;
  final String body;
  final String type; // 'request_update' | 'dispense' | 'low_stock' | 'announcement'
  final bool read;
  final DateTime createdAt;

  const NotificationItemModel({
    required this.id,
    required this.recipientUid,
    this.schoolId,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipientUid': recipientUid,
    if (schoolId != null) 'schoolId': schoolId,
    'title': title,
    'body': body,
    'type': type,
    'read': read,
    'createdAt': createdAt.toIso8601String(),
  };

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: (json['id'] ?? '').toString(),
      recipientUid: (json['recipientUid'] ?? '').toString(),
      schoolId: json['schoolId'] as String?,
      title: (json['title'] ?? 'Notification').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'announcement').toString(),
      read: json['read'] == true,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Firebase Cloud Messaging and notification delivery service.
class NotificationService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  /// Updates user device token for push notifications in `users/{uid}`.
  static Future<void> updateDeviceToken(String uid, String fcmToken) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('users').doc(uid).set({
        'fcmToken': fcmToken,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('NotificationService updateDeviceToken error: $e');
    }
  }

  /// Streams notifications for a specific user.
  static Stream<List<NotificationItemModel>> streamNotifications(String uid) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => NotificationItemModel.fromJson(doc.data())).toList())
        .handleError((e) {
          debugPrint('streamNotifications error: $e');
          return <NotificationItemModel>[];
        });
  }

  /// Marks a notification as read.
  static Future<void> markAsRead(String notificationId) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('notifications').doc(notificationId).update({'read': true});
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }
}
