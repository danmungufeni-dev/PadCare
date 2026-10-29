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
        return AuthResult(
          isSuccess: false,
          errorMessage: e.message ?? 'Authentication failed (${e.code}).',
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

    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        final credential = await _auth!.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );
        if (displayName != null && displayName.trim().isNotEmpty) {
          await credential.user?.updateDisplayName(displayName.trim());
        }
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
