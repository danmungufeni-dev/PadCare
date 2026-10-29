import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;
  final String? fallbackEmail;

  const AuthResult({
    required this.isSuccess,
    this.errorMessage,
    this.user,
    this.fallbackEmail,
  });
}

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'teacher' | 'parent' | 'admin'
  final String? school;
  final bool authorized;
  final String status; // 'pending' | 'approved' | 'rejected'

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.school,
    required this.authorized,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role,
    'school': school,
    'authorized': authorized,
    'status': status,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    uid: json['uid'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    role: json['role'] as String? ?? 'parent',
    school: json['school'] as String?,
    authorized: json['authorized'] as bool? ?? (json['role'] == 'parent'),
    status: json['status'] as String? ?? ((json['role'] == 'parent') ? 'approved' : 'pending'),
  );
}

class FirebaseService {
  static bool _initialized = false;
  static bool _firebaseAvailable = false;

  static bool get isFirebaseAvailable => _firebaseAvailable;

  /// Initializes Firebase safely with graceful offline/local fallback.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        'ℹ️ PadCare: Firebase is in local fallback mode. '
        'Add your Firebase keys in lib/firebase_options.dart to activate live cloud syncing.',
      );
      _firebaseAvailable = false;
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseAvailable = true;
      debugPrint('✅ PadCare: Firebase initialized successfully.');
    } catch (e, stack) {
      _firebaseAvailable = false;
      debugPrint('⚠️ PadCare: Firebase initialization fallback: $e');
      debugPrint('$stack');
    }
  }
}

class AuthService {
  static FirebaseAuth? get _auth =>
      FirebaseService.isFirebaseAvailable ? FirebaseAuth.instance : null;

  /// Signs in using Firebase Auth, or graceful local mock if offline/not configured.
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Please enter a valid email address.',
      );
    }
    if (password.trim().isEmpty) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Please enter your password.',
      );
    }

    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        final credential = await _auth!.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );
        return AuthResult(isSuccess: true, user: credential.user);
      } on FirebaseAuthException catch (e) {
        String msg = 'Invalid email or password. Please verify your credentials.';
        if (e.code == 'too-many-requests') {
          msg = 'Too many failed login attempts. Please wait a moment and try again.';
        } else if (e.code == 'user-disabled') {
          msg = 'This account has been disabled. Please contact PadCare administration.';
        }
        return AuthResult(
          isSuccess: false,
          errorMessage: msg,
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: 'An unexpected error occurred during login: $e',
        );
      }
    }

    // Local / Offline fallback mode
    return AuthResult(
      isSuccess: true,
      fallbackEmail: cleanEmail,
    );
  }

  /// Registers a new account with Firebase Auth, or graceful local mock.
  static Future<AuthResult> register({
    required String email,
    required String password,
    String? displayName,
    String role = 'parent',
    String? school,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Email is required for registration.',
      );
    }
    if (password.trim().length < 6) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Password must be at least 6 characters.',
      );
    }

    final isParent = role != 'teacher';

    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        final credential = await _auth!.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );
        if (displayName != null && displayName.trim().isNotEmpty) {
          await credential.user?.updateDisplayName(displayName.trim());
        }

        final uid = credential.user?.uid ?? cleanEmail;
        final profile = UserProfile(
          uid: uid,
          email: cleanEmail,
          displayName: displayName?.trim() ?? '',
          role: role,
          school: school,
          authorized: isParent, // Teachers require backend authorization in Firebase
          status: isParent ? 'approved' : 'pending_approval',
        );
        await FirestoreService.saveUserProfile(profile);

        return AuthResult(isSuccess: true, user: credential.user);
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: e.message ?? 'Registration failed (${e.code}).',
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: 'An unexpected error occurred during registration: $e',
        );
      }
    }

    final localProfile = UserProfile(
      uid: 'offline-$cleanEmail',
      email: cleanEmail,
      displayName: displayName?.trim() ?? '',
      role: role,
      school: school,
      authorized: isParent,
      status: isParent ? 'approved' : 'pending_approval',
    );
    await FirestoreService.saveUserProfile(localProfile);

    return AuthResult(
      isSuccess: true,
      fallbackEmail: cleanEmail,
    );
  }

  /// Signs in or registers with Google Auth, incorporating Google account details.
  static Future<AuthResult> signInWithGoogle() async {
    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final UserCredential credential = await _auth!.signInWithPopup(googleProvider);
        return AuthResult(isSuccess: true, user: credential.user);
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: e.message ?? 'Google Sign-In failed (${e.code}).',
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: 'Google Sign-In error: $e',
        );
      }
    }

    // Graceful offline mock incorporation
    return const AuthResult(
      isSuccess: true,
      fallbackEmail: 'google.account@gmail.com',
    );
  }

  /// Signs the user out of Firebase and clears local session.
  static Future<void> signOut() async {
    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      await _auth!.signOut();
    }
  }

  /// Returns the currently authenticated Firebase user, if any.
  static User? get currentUser => _auth?.currentUser;
}

class FirestoreService {
  static FirebaseFirestore? get _db =>
      FirebaseService.isFirebaseAvailable ? FirebaseFirestore.instance : null;

  static final Map<String, UserProfile> _offlineProfiles = {};

  /// Saves or updates user profile in `users/{uid}`
  static Future<void> saveUserProfile(UserProfile profile) async {
    _offlineProfiles[profile.uid] = profile;
    _offlineProfiles[profile.email] = profile;
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      await _db!.collection('users').doc(profile.uid).set({
        ...profile.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveUserProfile error: $e');
    }
  }

  /// Fetches user profile from Firestore `users/{uid}` or offline cache
  static Future<UserProfile?> getUserProfile(String uidOrEmail) async {
    if (_offlineProfiles.containsKey(uidOrEmail)) {
      return _offlineProfiles[uidOrEmail];
    }
    if (!FirebaseService.isFirebaseAvailable || _db == null) return null;
    try {
      final doc = await _db!.collection('users').doc(uidOrEmail).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromJson(doc.data()!);
      }
      final query = await _db!
          .collection('users')
          .where('email', isEqualTo: uidOrEmail)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return UserProfile.fromJson(query.docs.first.data());
      }
    } catch (e) {
      debugPrint('Firestore getUserProfile error: $e');
    }
    return null;
  }

  /// Saves or updates a menstrual care pad distribution request in Firestore.
  static Future<void> saveRequest(Map<String, dynamic> requestData) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;

    try {
      final id = requestData['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      await _db!.collection('requests').doc(id).set(
        {
          ...requestData,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Firestore saveRequest error: $e');
    }
  }

  /// Updates status of a request (e.g. pending, approved, ready, collected).
  static Future<void> updateRequestStatus(String requestId, String status) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;

    try {
      await _db!.collection('requests').doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore updateRequestStatus error: $e');
    }
  }

  /// Updates stock level for a school in Firestore.
  static Future<void> updateSchoolStock({
    required String schoolName,
    required int kitsOnHand,
    required int packsOnHand,
  }) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;

    try {
      await _db!.collection('schools').doc(schoolName).set({
        'name': schoolName,
        'kitsOnHand': kitsOnHand,
        'packsOnHand': packsOnHand,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updateSchoolStock error: $e');
    }
  }
}
