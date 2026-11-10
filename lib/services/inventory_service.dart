import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// School inventory item model
class InventoryItemModel {
  final String id;
  final String schoolId;
  final String productId;
  final String productName;
  final int availableQuantity;
  final int reservedQuantity;
  final int totalReceived;
  final int totalDistributed;
  final String unit;
  final int lowStockThreshold;
  final DateTime lastUpdated;

  const InventoryItemModel({
    required this.id,
    required this.schoolId,
    required this.productId,
    required this.productName,
    required this.availableQuantity,
    this.reservedQuantity = 0,
    this.totalReceived = 0,
    this.totalDistributed = 0,
    this.unit = 'packs',
    this.lowStockThreshold = 10,
    required this.lastUpdated,
  });

  bool get isLowStock => availableQuantity <= lowStockThreshold;

  Map<String, dynamic> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'productId': productId,
    'productName': productName,
    'availableQuantity': availableQuantity,
    'reservedQuantity': reservedQuantity,
    'totalReceived': totalReceived,
    'totalDistributed': totalDistributed,
    'unit': unit,
    'lowStockThreshold': lowStockThreshold,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      id: (json['id'] ?? '').toString(),
      schoolId: (json['schoolId'] ?? '').toString(),
      productId: (json['productId'] ?? 'disposable-pads').toString(),
      productName: (json['productName'] ?? 'Disposable pads').toString(),
      availableQuantity: (json['availableQuantity'] is num) ? (json['availableQuantity'] as num).toInt() : 0,
      reservedQuantity: (json['reservedQuantity'] is num) ? (json['reservedQuantity'] as num).toInt() : 0,
      totalReceived: (json['totalReceived'] is num) ? (json['totalReceived'] as num).toInt() : 0,
      totalDistributed: (json['totalDistributed'] is num) ? (json['totalDistributed'] as num).toInt() : 0,
      unit: (json['unit'] ?? 'packs').toString(),
      lowStockThreshold: (json['lowStockThreshold'] is num) ? (json['lowStockThreshold'] as num).toInt() : 10,
      lastUpdated: json['lastUpdated'] != null
          ? (DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Distribution transaction record for audit logs
class DistributionRecordModel {
  final String distributionId;
  final String requestId;
  final String reference;
  final String pickupPin;
  final String schoolId;
  final String schoolName;
  final String productId;
  final int quantity;
  final String dispensedBy;
  final DateTime dispensedAt;
  final String status;

  const DistributionRecordModel({
    required this.distributionId,
    required this.requestId,
    required this.reference,
    required this.pickupPin,
    required this.schoolId,
    required this.schoolName,
    required this.productId,
    required this.quantity,
    required this.dispensedBy,
    required this.dispensedAt,
    this.status = 'completed',
  });

  Map<String, dynamic> toJson() => {
    'distributionId': distributionId,
    'requestId': requestId,
    'reference': reference,
    'pickupPin': pickupPin,
    'schoolId': schoolId,
    'school': schoolName,
    'productId': productId,
    'quantity': quantity,
    'dispensedBy': dispensedBy,
    'dispensedAt': dispensedAt.toIso8601String(),
    'status': status,
  };

  factory DistributionRecordModel.fromJson(Map<String, dynamic> json) {
    return DistributionRecordModel(
      distributionId: (json['distributionId'] ?? json['id'] ?? '').toString(),
      requestId: (json['requestId'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      pickupPin: (json['pickupPin'] ?? '').toString(),
      schoolId: (json['schoolId'] ?? '').toString(),
      schoolName: (json['school'] ?? '').toString(),
      productId: (json['productId'] ?? 'disposable-pads').toString(),
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1,
      dispensedBy: (json['dispensedBy'] ?? 'Staff').toString(),
      dispensedAt: json['dispensedAt'] != null
          ? (DateTime.tryParse(json['dispensedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: (json['status'] ?? 'completed').toString(),
    );
  }
}

/// Traceable stock movement transaction log
class StockMovementModel {
  final String movementId;
  final String schoolId;
  final String productId;
  final int quantityChange;
  final int previousStock;
  final int newStock;
  final String reason; // 'student_dispense' | 'restock' | 'damage' | 'adjustment'
  final String referenceId;
  final String? pickupPin;
  final String performedBy;
  final DateTime timestamp;

  const StockMovementModel({
    required this.movementId,
    required this.schoolId,
    required this.productId,
    required this.quantityChange,
    required this.previousStock,
    required this.newStock,
    required this.reason,
    required this.referenceId,
    this.pickupPin,
    required this.performedBy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'movementId': movementId,
    'schoolId': schoolId,
    'productId': productId,
    'quantityChange': quantityChange,
    'previousStock': previousStock,
    'newStock': newStock,
    'reason': reason,
    'referenceId': referenceId,
    if (pickupPin != null) 'pickupPin': pickupPin,
    'performedBy': performedBy,
    'timestamp': timestamp.toIso8601String(),
  };

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    return StockMovementModel(
      movementId: (json['movementId'] ?? json['id'] ?? '').toString(),
      schoolId: (json['schoolId'] ?? json['school'] ?? '').toString(),
      productId: (json['productId'] ?? 'disposable-pads').toString(),
      quantityChange: (json['quantityChange'] is num) ? (json['quantityChange'] as num).toInt() : 0,
      previousStock: (json['previousStock'] is num) ? (json['previousStock'] as num).toInt() : 0,
      newStock: (json['newStock'] is num) ? (json['newStock'] as num).toInt() : 0,
      reason: (json['reason'] ?? 'adjustment').toString(),
      referenceId: (json['referenceId'] ?? '').toString(),
      pickupPin: json['pickupPin']?.toString(),
      performedBy: (json['performedBy'] ?? 'Staff').toString(),
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Inventory and distribution service with atomic transaction protection.
class InventoryService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  /// Executes atomic dispensing transaction with double-dispense and stock protection.
  static Future<Map<String, dynamic>> dispenseAtomic({
    required String requestId,
    required String schoolName,
    required String product,
    required int quantity,
    required String dispensedBy,
    required String pin,
  }) async {
    return FirestoreService.dispenseRequestAtomic(
      requestId: requestId,
      school: schoolName,
      product: product,
      quantity: quantity,
      dispensedBy: dispensedBy,
      pin: pin,
    );
  }

  /// Streams completed distributions for an individual school.
  static Stream<List<DistributionRecordModel>> streamDistributions(String schoolName) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('dispensations')
        .where('school', isEqualTo: schoolName)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DistributionRecordModel.fromJson(doc.data())).toList())
        .handleError((e) {
          debugPrint('streamDistributions error: $e');
          return <DistributionRecordModel>[];
        });
  }

  /// Streams traceable stock movements for an individual school.
  static Stream<List<StockMovementModel>> streamStockMovements(String schoolName) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('stock_movements')
        .where('schoolId', isEqualTo: schoolName)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => StockMovementModel.fromJson(doc.data())).toList())
        .handleError((e) {
          debugPrint('streamStockMovements error: $e');
          return <StockMovementModel>[];
        });
  }
}
