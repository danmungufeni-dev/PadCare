import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'school_service.dart';

class OfflineTask {
  final String id;
  final String type; // 'save_request' | 'update_request_status' | 'update_school_stock' | 'restock_request'
  final Map<String, dynamic> payload;
  final String timestamp;
  int attempts;

  OfflineTask({
    required this.id,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'timestamp': timestamp,
    'attempts': attempts,
  };

  factory OfflineTask.fromJson(Map<String, dynamic> json) => OfflineTask(
    id: json['id'] as String? ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
    type: json['type'] as String? ?? 'save_request',
    payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
  );
}

class OfflineQueueService {
  static const String _queueKey = 'padcare.offlineQueue.v1';
  static final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  static final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  static Timer? _syncTimer;
  static bool _initialized = false;

  /// Initializes the offline queue and starts automatic periodic background sync.
  static Future<void> init({bool isTest = false}) async {
    if (_initialized) return;
    _initialized = true;

    final tasks = await _loadQueue();
    pendingCount.value = tasks.length;

    if (!isTest) {
      // Auto-flush every 25 seconds if there are pending items
      _syncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (pendingCount.value > 0 && !isSyncing.value) {
          flush();
        }
      });
      // Initial attempt on startup
      if (tasks.isNotEmpty) {
        unawaited(flush());
      }
    }
  }

  /// Adds a mutation to the persistent offline queue and triggers a sync attempt.
  static Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final task = OfflineTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}_${payload['id'] ?? ''}',
      type: type,
      payload: payload,
      timestamp: DateTime.now().toIso8601String(),
    );

    final tasks = await _loadQueue();
    tasks.add(task);
    await _saveQueue(tasks);
    pendingCount.value = tasks.length;

    // Trigger immediate background sync attempt
    unawaited(flush());
  }

  /// Flushes pending offline tasks to Cloud Firestore.
  static Future<int> flush() async {
    if (isSyncing.value) return 0;
    isSyncing.value = true;

    int syncedCount = 0;
    try {
      final tasks = await _loadQueue();
      if (tasks.isEmpty) {
        pendingCount.value = 0;
        isSyncing.value = false;
        return 0;
      }

      final List<OfflineTask> remaining = [];

      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        bool success = false;
        try {
          switch (task.type) {
            case 'save_request':
              await FirestoreService.saveRequest(task.payload);
              success = true;
              break;
            case 'update_request_status':
              final reqId = task.payload['id']?.toString() ?? '';
              final status = task.payload['status']?.toString() ?? '';
              if (reqId.isNotEmpty) {
                await FirestoreService.updateRequestStatus(reqId, status);
              }
              success = true;
              break;
            case 'update_school_stock':
              final school = task.payload['school']?.toString() ?? '';
              final kits = (task.payload['kitsOnHand'] as num?)?.toInt() ?? 0;
              final packs = (task.payload['packsOnHand'] as num?)?.toInt() ?? 0;
              if (school.isNotEmpty) {
                await FirestoreService.updateSchoolStock(
                  schoolName: school,
                  kitsOnHand: kits,
                  packsOnHand: packs,
                );
              }
              success = true;
              break;
            case 'restock_request':
              await FirestoreService.saveRestockRequest(task.payload);
              success = true;
              break;
            case 'save_school':
              final school = SchoolModel.fromJson(task.payload);
              await SchoolService.saveSchool(school, enqueueOffline: false);
              success = true;
              break;
            default:
              success = true;
          }
        } catch (e) {
          debugPrint('OfflineQueueService sync task failed: $e');
          task.attempts++;
          success = false;
        }

        if (success) {
          syncedCount++;
        } else {
          // If a task fails (e.g. offline network timeout), preserve it and remaining items
          remaining.add(task);
          remaining.addAll(tasks.sublist(i + 1));
          break;
        }
      }

      await _saveQueue(remaining);
      pendingCount.value = remaining.length;
    } catch (e) {
      debugPrint('OfflineQueueService flush error: $e');
    } finally {
      isSyncing.value = false;
    }

    return syncedCount;
  }

  static Future<List<OfflineTask>> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => OfflineTask.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error reading offline queue: $e');
    }
    return [];
  }

  static Future<void> _saveQueue(List<OfflineTask> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (tasks.isEmpty) {
        await prefs.remove(_queueKey);
      } else {
        await prefs.setString(
          _queueKey,
          jsonEncode(tasks.map((t) => t.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('Error saving offline queue: $e');
    }
  }

  /// Returns a snapshot of all pending offline tasks for UI inspection.
  static Future<List<OfflineTask>> getPendingTasks() async {
    return _loadQueue();
  }

  /// Removes a specific task from the offline queue.
  static Future<void> removeTask(String id) async {
    final tasks = await _loadQueue();
    tasks.removeWhere((t) => t.id == id);
    await _saveQueue(tasks);
    pendingCount.value = tasks.length;
  }

  /// Clears all pending offline tasks.
  static Future<void> clearQueue() async {
    await _saveQueue([]);
    pendingCount.value = 0;
  }

  /// Persists an in-progress form draft to survive interruptions and offline restarts.
  static Future<void> saveDraft(String formKey, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('padcare.draft.$formKey', jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving form draft: $e');
    }
  }

  /// Retrieves an in-progress draft if one was previously saved.
  static Future<Map<String, dynamic>?> getDraft(String formKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('padcare.draft.$formKey');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      debugPrint('Error reading form draft: $e');
    }
    return null;
  }

  /// Clears an in-progress form draft once successfully submitted.
  static Future<void> clearDraft(String formKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('padcare.draft.$formKey');
    } catch (e) {
      debugPrint('Error clearing form draft: $e');
    }
  }

  /// Cancels background timer (e.g. on test dispose).
  static void dispose() {
    _syncTimer?.cancel();
    _initialized = false;
  }
}

/// Offline cache manager for storing educational guides, FAQs, and school directories locally.
class OfflineCacheService {
  static const String _kGuideCacheKey = 'padcare.offline.guides.v1';
  static const String _kFaqCacheKey = 'padcare.offline.faqs.v1';
  static const String _kFacilitiesCacheKey = 'padcare.offline.facilities.v1';
  static const String _kCacheMetaKey = 'padcare.offline.cache.meta.v1';

  static final ValueNotifier<bool> isOfflineReady = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> lastSyncTime = ValueNotifier<String?>(null);

  /// Initializes cache status from storage
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final meta = prefs.getString(_kCacheMetaKey);
      if (meta != null) {
        final decoded = jsonDecode(meta);
        if (decoded is Map) {
          isOfflineReady.value = true;
          lastSyncTime.value = decoded['syncedAt'] as String?;
        }
      }
    } catch (_) {}
  }

  /// Caches educational guides, FAQ list, and local school facilities for 100% offline access.
  static Future<bool> preCacheAllResources({
    List<Map<String, dynamic>>? guides,
    List<Map<String, dynamic>>? faqs,
    List<Map<String, dynamic>>? facilities,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();

      if (guides != null) {
        await prefs.setString(_kGuideCacheKey, jsonEncode(guides));
      }
      if (faqs != null) {
        await prefs.setString(_kFaqCacheKey, jsonEncode(faqs));
      }
      if (facilities != null) {
        await prefs.setString(_kFacilitiesCacheKey, jsonEncode(facilities));
      }

      await prefs.setString(_kCacheMetaKey, jsonEncode({
        'syncedAt': now,
        'guidesCount': guides?.length ?? 0,
        'faqsCount': faqs?.length ?? 0,
        'facilitiesCount': facilities?.length ?? 0,
      }));

      isOfflineReady.value = true;
      lastSyncTime.value = now;
      return true;
    } catch (e) {
      debugPrint('Error caching offline resources: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> getCachedGuides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kGuideCacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>?> getCachedFaqs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFaqCacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>?> getCachedFacilities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFacilitiesCacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return null;
  }
}
