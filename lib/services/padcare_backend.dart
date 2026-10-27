import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase adapter for PadCare. The app intentionally remains usable offline
/// when Firebase platform configuration has not been added yet.
class PadCareBackend {
  PadCareBackend._();

  static bool _initialized = false;
  static Object? _initializationError;

  static bool get isConfigured => _initialized;
  static bool get isSignedIn => _initialized && FirebaseAuth.instance.currentUser != null;
  static User? get currentUser => _initialized ? FirebaseAuth.instance.currentUser : null;
  static String? get currentUserId => currentUser?.uid;
  static String get currentDisplayName {
    final user = currentUser;
    return user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'PadCare user');
  }
  static String? get configurationMessage => _initializationError?.toString();

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _initialized = true;
      _initializationError = null;
    } catch (error) {
      _initialized = false;
      _initializationError = error;
    }
  }

  static FirebaseAuth get _auth {
    if (!_initialized) throw StateError('Firebase is not configured for this platform.');
    return FirebaseAuth.instance;
  }

  static FirebaseFirestore get _db {
    if (!_initialized) throw StateError('Firebase is not configured for this platform.');
    return FirebaseFirestore.instance;
  }

  static Future<void> createParentAccount({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
    }
    final user = credential.user;
    if (user == null) throw StateError('Account was created but no user session was returned.');
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': name ?? '',
      'role': 'parent',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signOut() async {
    if (_initialized) await FirebaseAuth.instance.signOut();
  }

  /// Saves only the minimum anonymous pickup-request details. The caller must
  /// keep its local copy when this remote write fails.
  static Future<void> createPickupRequest(Map<String, Object?> request) async {
    final user = currentUser;
    if (user == null) throw StateError('Sign in before syncing a request.');
    final id = request['id']?.toString();
    if (id == null || id.isEmpty) throw ArgumentError('A request ID is required.');
    await _db.collection('requests').doc(id).set({
      'id': id,
      'reference': request['reference'],
      'school': request['school'],
      'schoolId': _slug(request['school']?.toString() ?? ''),
      'area': request['area'],
      'product': request['product'],
      'quantity': request['quantity'],
      'createdAt': request['createdAt'],
      'status': 'Pending review',
      'userId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deletePickupRequest(String id) async {
    final user = currentUser;
    if (user == null) throw StateError('Sign in before syncing a request.');
    await _db.collection('requests').doc(id).delete();
  }

  static Future<void> updatePickupRequestStatus({
    required String id,
    required String status,
  }) async {
    if (currentUser == null) throw StateError('Sign in before syncing a request.');
    const allowed = {'Pending review', 'Approved', 'Declined', 'Ready for pickup', 'Collected'};
    if (!allowed.contains(status)) throw ArgumentError('Unsupported request status.');
    await _db.collection('requests').doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateInventory({
    required String facilityId,
    required String product,
    required int onHand,
    required int reserved,
  }) async {
    if (currentUser == null) throw StateError('Sign in before syncing inventory.');
    if (onHand < 0 || reserved < 0 || reserved > onHand) {
      throw ArgumentError('Inventory counts are invalid.');
    }
    await _db.collection('facilities').doc(facilityId)
        .collection('inventory').doc(_slug(product)).set({
      'product': product,
      'onHand': onHand,
      'reserved': reserved,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Only verified providers should be queried by the client. Firestore rules
  /// also enforce this; a client-side filter alone is not a security boundary.
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchVerifiedProviders() {
    return _db.collection('facilities')
        .where('isVerified', isEqualTo: true)
        .snapshots();
  }

  static Future<void> recordDonationPledge({
    required int amountUgx,
    required String purpose,
  }) async {
    final user = currentUser;
    if (user == null) throw StateError('Sign in to record a pledge.');
    if (amountUgx <= 0) throw ArgumentError('Pledge amount must be positive.');
    await _db.collection('donationPledges').add({
      'userId': user.uid,
      'amountUgx': amountUgx,
      'purpose': purpose,
      'status': 'pledged',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static String _slug(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
