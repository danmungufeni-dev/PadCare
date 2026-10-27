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
  static Future<Map<String, dynamic>> loadCurrentProfile() async {
    final user = currentUser;
    if (user == null) return <String, dynamic>{'role': 'parent'};
    final snapshot = await _db.collection('users').doc(user.uid).get();
    return snapshot.data() ?? <String, dynamic>{'role': 'parent'};
  }

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

  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
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

  static Future<List<Map<String, dynamic>>> loadMyRequests() async {
    final user = currentUser;
    if (user == null) return <Map<String, dynamic>>[];
    final snapshot = await _db.collection('requests')
        .where('userId', isEqualTo: user.uid)
        .get();
    return snapshot.docs.map((doc) => <String, dynamic>{
      ...doc.data(),
      'id': doc.id,
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> loadFacilityRequests(String facilityId) async {
    final profile = await loadCurrentProfile();
    if (profile['role'] != 'schoolStaff' || profile['facilityId'] != facilityId) {
      throw StateError('This account is not authorised for that facility.');
    }
    final snapshot = await _db.collection('requests')
        .where('schoolId', isEqualTo: facilityId)
        .get();
    return snapshot.docs.map((doc) => <String, dynamic>{
      ...doc.data(),
      'id': doc.id,
    }).toList();
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

  static Future<Map<String, Map<String, int>>> loadInventory(String facilityId) async {
    final profile = await loadCurrentProfile();
    if (profile['role'] != 'schoolStaff' || profile['facilityId'] != facilityId) {
      throw StateError('This account is not authorised for that facility.');
    }
    final snapshot = await _db.collection('facilities').doc(facilityId)
        .collection('inventory').get();
    final inventory = <String, Map<String, int>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final product = data['product']?.toString();
      if (product == null || product.isEmpty) continue;
      inventory[product] = {
        'onHand': (data['onHand'] as num?)?.toInt() ?? 0,
        'reserved': (data['reserved'] as num?)?.toInt() ?? 0,
      };
    }
    return inventory;
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
    final facility = _db.collection('facilities').doc(facilityId);
    await facility.collection('inventory').doc(_slug(product)).set({
      'product': product,
      'onHand': onHand,
      'reserved': reserved,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Aggregate all products so the public summary is not overwritten by
    // a single product that happens to be out of stock.
    final inventorySnapshot = await facility.collection('inventory').get();
    final anyAvailable = inventorySnapshot.docs.any((doc) {
      final data = doc.data();
      final itemOnHand = (data['onHand'] as num?)?.toInt() ?? 0;
      final itemReserved = (data['reserved'] as num?)?.toInt() ?? 0;
      return itemOnHand > itemReserved;
    });
    await facility.set({
      'stockAvailable': anyAvailable,
      'stockUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Only verified providers should be queried by the client. Firestore rules
  /// also enforce this; a client-side filter alone is not a security boundary.
  static Stream<List<Map<String, dynamic>>> watchVerifiedProviders() {
    return _db.collection('facilities')
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              final updated = data['stockUpdatedAt'];
              if (updated is Timestamp) {
                data['stockUpdatedAtIso'] = updated.toDate().toIso8601String();
              }
              return data;
            }).toList());
  }

  /// Submits a provider listing for review. This creates an application only;
  /// it never creates a public facility or grants verification/staff privileges.
  static Future<String> submitProviderApplication({
    required String organisationName,
    required String facilityName,
    required String area,
    required String address,
    required String description,
    String pickupInstructions = '',
  }) async {
    final user = currentUser;
    if (user == null) throw StateError('Sign in before submitting a provider application.');
    final email = user.email;
    if (email == null || email.trim().isEmpty) {
      throw StateError('Add and verify an email address before applying.');
    }
    final values = <String, String>{
      'organisationName': organisationName.trim(),
      'facilityName': facilityName.trim(),
      'area': area.trim(),
      'address': address.trim(),
      'description': description.trim(),
      'pickupInstructions': pickupInstructions.trim(),
    };
    if (values['organisationName']!.isEmpty ||
        values['facilityName']!.isEmpty ||
        values['area']!.isEmpty ||
        values['address']!.isEmpty ||
        values['description']!.isEmpty) {
      throw ArgumentError('Complete all required provider application fields.');
    }
    final ref = await _db.collection('providerApplications').add({
      ...values,
      'contactEmail': email.trim(),
      'userId': user.uid,
      'status': 'submitted',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Lists only the signed-in user's provider applications. Application status
  /// can be changed only by a trusted administrator outside this client API.
  static Future<List<Map<String, dynamic>>> loadMyProviderApplications() async {
    final user = currentUser;
    if (user == null) throw StateError('Sign in to view provider applications.');
    final snapshot = await _db.collection('providerApplications')
        .where('userId', isEqualTo: user.uid)
        .get();
    return snapshot.docs.map((doc) => <String, dynamic>{
      ...doc.data(),
      'id': doc.id,
    }).toList();
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
