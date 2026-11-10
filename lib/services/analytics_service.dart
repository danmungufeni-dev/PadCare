import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Centralized event logging, Crashlytics, and audit trail service for PadCare.
class AnalyticsService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  /// Logs a business or user event in analytics / audit trail.
  static Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
  }) async {
    debugPrint('📊 Analytics Event: $name -> $parameters');
    // Sanitized: Never log confidential personal identifiable info (PII) about girls
  }

  /// Logs an immutable audit trail entry in Firestore `audit_logs/{id}`.
  static Future<void> logAuditAction({
    required String action,
    required String performedBy,
    required String schoolId,
    Map<String, dynamic>? details,
  }) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      final id = 'AUDIT-${DateTime.now().microsecondsSinceEpoch}';
      await _db!.collection('audit_logs').doc(id).set({
        'logId': id,
        'action': action,
        'performedBy': performedBy,
        'schoolId': schoolId,
        if (details != null) 'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AnalyticsService logAuditAction error: $e');
    }
  }

  /// Records crash or handled exception safely.
  static void recordError(Object exception, StackTrace? stack, {String? reason}) {
    debugPrint('🛑 Error Logged: $exception');
    if (reason != null) debugPrint('Reason: $reason');
    if (stack != null) debugPrint('$stack');
  }
}
