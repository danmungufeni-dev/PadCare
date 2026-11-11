import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Notification model in Firestore `notifications/{id}`
class NotificationItemModel {
  final String id;
  final String recipientUid;
  final String? schoolId;
  final String? schoolName;
  final String title;
  final String body;
  final String type; // 'request_update' | 'dispense' | 'low_stock' | 'announcement'
  final String urgency; // 'urgent' | 'warning' | 'info'
  final int? currentStock;
  final int? threshold;
  final bool read;
  final DateTime createdAt;

  const NotificationItemModel({
    required this.id,
    required this.recipientUid,
    this.schoolId,
    this.schoolName,
    required this.title,
    required this.body,
    required this.type,
    this.urgency = 'info',
    this.currentStock,
    this.threshold,
    this.read = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipientUid': recipientUid,
    if (schoolId != null) 'schoolId': schoolId,
    if (schoolName != null) 'schoolName': schoolName,
    'title': title,
    'body': body,
    'type': type,
    'urgency': urgency,
    if (currentStock != null) 'currentStock': currentStock,
    if (threshold != null) 'threshold': threshold,
    'read': read,
    'createdAt': createdAt.toIso8601String(),
  };

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: (json['id'] ?? '').toString(),
      recipientUid: (json['recipientUid'] ?? '').toString(),
      schoolId: json['schoolId'] as String?,
      schoolName: json['schoolName'] as String?,
      title: (json['title'] ?? 'Notification').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'announcement').toString(),
      urgency: (json['urgency'] ?? 'info').toString(),
      currentStock: (json['currentStock'] as num?)?.toInt(),
      threshold: (json['threshold'] as num?)?.toInt(),
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

  static final List<NotificationItemModel> _memoryAlerts = [
    NotificationItemModel(
      id: 'alert-logiri-restock',
      recipientUid: 'all_partners',
      schoolId: 'logiri-girls-secondary',
      schoolName: 'Logiri Girls Secondary',
      title: 'Critical Restock Alert: Logiri Girls Secondary',
      body: 'Stock is down to 18 packs (3 days supply remaining). 120 girls need restock support.',
      type: 'low_stock',
      urgency: 'urgent',
      currentStock: 18,
      threshold: 30,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    NotificationItemModel(
      id: 'alert-mvara-restock',
      recipientUid: 'all_partners',
      schoolId: 'mvara-secondary',
      schoolName: 'Mvara Secondary',
      title: 'Low Stock Warning: Mvara Secondary',
      body: 'Stock has fallen to 45 packs (threshold is 50). Hub requisition pending.',
      type: 'low_stock',
      urgency: 'warning',
      currentStock: 45,
      threshold: 50,
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
  ];

  /// Evaluates inventory levels and triggers a restock alert if stock <= threshold.
  static Future<NotificationItemModel?> checkAndGenerateRestockAlert({
    required String schoolId,
    required String schoolName,
    required int currentStock,
    required int threshold,
  }) async {
    if (currentStock > threshold) return null;

    final isUrgent = currentStock <= (threshold * 0.5);
    final alert = NotificationItemModel(
      id: 'alert-$schoolId-${DateTime.now().millisecondsSinceEpoch}',
      recipientUid: 'all_partners',
      schoolId: schoolId,
      schoolName: schoolName,
      title: isUrgent ? 'Critical Restock Alert: $schoolName' : 'Low Stock Warning: $schoolName',
      body: 'Stock is at $currentStock packs (threshold: $threshold). Sponsor a restock to ensure supply continuity.',
      type: 'low_stock',
      urgency: isUrgent ? 'urgent' : 'warning',
      currentStock: currentStock,
      threshold: threshold,
      createdAt: DateTime.now(),
    );

    _memoryAlerts.insert(0, alert);

    if (FirebaseService.isFirebaseAvailable && _db != null) {
      try {
        await _db!.collection('notifications').doc(alert.id).set(alert.toJson());
      } catch (e) {
        debugPrint('checkAndGenerateRestockAlert error: $e');
      }
    }
    return alert;
  }

  /// Streams active low stock alerts for NGOs and Staff
  static Stream<List<NotificationItemModel>> streamRestockAlerts() {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return Stream.value(_memoryAlerts.where((a) => !a.read).toList());
    }
    return _db!
        .collection('notifications')
        .where('type', isEqualTo: 'low_stock')
        .snapshots()
        .map((snap) {
          final docs = snap.docs.map((d) => NotificationItemModel.fromJson(d.data())).toList();
          if (docs.isEmpty) return _memoryAlerts.where((a) => !a.read).toList();
          return docs.where((a) => !a.read).toList();
        })
        .handleError((e) {
          debugPrint('streamRestockAlerts error: $e');
          return _memoryAlerts.where((a) => !a.read).toList();
        });
  }

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
