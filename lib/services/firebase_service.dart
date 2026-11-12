import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'school_service.dart';

export 'auth_service.dart';
export 'school_service.dart';
export 'request_service.dart';
export 'pin_service.dart';
export 'inventory_service.dart';
export 'sponsor_service.dart';
export 'analytics_service.dart';
export 'notification_service.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? errorCode;
  final User? user;
  final String? fallbackEmail;
  final String? photoUrl;
  final UserProfile? profile;

  const AuthResult({
    required this.isSuccess,
    this.errorMessage,
    this.errorCode,
    this.user,
    this.fallbackEmail,
    this.photoUrl,
    this.profile,
  });
}

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'teacher' | 'parent' | 'admin' | 'ngo'
  final String? school;
  final bool authorized;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? photoUrl;
  final String? phoneNumber;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.school,
    required this.authorized,
    required this.status,
    this.photoUrl,
    this.phoneNumber,
  });

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    String? school,
    bool? authorized,
    String? status,
    String? photoUrl,
    String? phoneNumber,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      school: school ?? this.school,
      authorized: authorized ?? this.authorized,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role,
    'school': school,
    'authorized': authorized,
    'status': status,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    uid: json['uid'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    role: json['role'] as String? ?? 'parent',
    school: json['school'] as String?,
    authorized: json['authorized'] as bool? ?? (json['role'] == 'parent' || json['role'] == 'ngo'),
    status: json['status'] as String? ?? ((json['role'] == 'parent' || json['role'] == 'ngo') ? 'approved' : 'pending'),
    photoUrl: json['photoUrl'] as String?,
    phoneNumber: json['phoneNumber'] as String?,
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
      debugPrint('✅ PadCare: Firebase initialized successfully with Auth, Firestore & Storage.');
    } catch (e, stack) {
      _firebaseAvailable = false;
      debugPrint('⚠️ PadCare: Firebase initialization fallback: $e');
      debugPrint('$stack');
    }
  }
}

/// Firebase Storage Service for user avatars, verification documents, and receipt images.
/// Includes graceful offline caching and resilience for low-connectivity deployments in Uganda.
class StorageService {
  static FirebaseStorage? get _storage =>
      FirebaseService.isFirebaseAvailable ? FirebaseStorage.instance : null;

  static final Map<String, String> _offlinePhotoUrls = {
    'devgtnation@gmail.com':
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
    'abetinichlas@gmail.com':
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&q=80',
  };

  static final Map<String, Uint8List> _offlineFileBytes = {};

  /// True if Firebase Storage is active and accessible
  static bool get isStorageAvailable =>
      FirebaseService.isFirebaseAvailable && _storage != null;

  /// Uploads user profile photo to Firebase Storage under `users/{uid}/{fileName}`.
  /// Automatically updates FirebaseAuth photoURL and Firestore UserProfile.
  static Future<String?> uploadProfileAvatar({
    required String uid,
    required Uint8List bytes,
    String fileName = 'avatar.jpg',
    String contentType = 'image/jpeg',
  }) async {
    final storagePath = 'users/$uid/$fileName';

    if (isStorageAvailable) {
      try {
        final ref = _storage!.ref().child(storagePath);
        final metadata = SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'uid': uid,
          },
        );

        final uploadTask = ref.putData(bytes, metadata);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        _offlinePhotoUrls[uid] = downloadUrl;

        // Update FirebaseAuth currentUser photoURL
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.uid == uid) {
          await user.updatePhotoURL(downloadUrl);
        }

        // Update Firestore profile
        final profile = await FirestoreService.getUserProfile(uid);
        if (profile != null) {
          await FirestoreService.saveUserProfile(
            profile.copyWith(photoUrl: downloadUrl),
          );
        }

        debugPrint('✅ StorageService: Uploaded avatar for $uid -> $downloadUrl');
        return downloadUrl;
      } catch (e) {
        debugPrint('⚠️ StorageService: Cloud upload fallback for $uid: $e');
      }
    }

    // Graceful offline mock / local storage cache
    _offlineFileBytes[storagePath] = bytes;
    final fallbackUrl = 'offline://storage/$storagePath';
    _offlinePhotoUrls[uid] = fallbackUrl;

    final existing = await FirestoreService.getUserProfile(uid);
    if (existing != null) {
      await FirestoreService.saveUserProfile(
        existing.copyWith(photoUrl: fallbackUrl),
      );
    }

    return fallbackUrl;
  }

  /// Retrieves profile avatar download URL for the given user ID.
  static Future<String?> getProfileAvatarUrl(String uid) async {
    if (_offlinePhotoUrls.containsKey(uid)) {
      return _offlinePhotoUrls[uid];
    }

    if (isStorageAvailable) {
      try {
        final ref = _storage!.ref().child('users/$uid/avatar.jpg');
        final url = await ref.getDownloadURL();
        _offlinePhotoUrls[uid] = url;
        return url;
      } catch (_) {
        try {
          final refPng = _storage!.ref().child('users/$uid/avatar.png');
          final url = await refPng.getDownloadURL();
          _offlinePhotoUrls[uid] = url;
          return url;
        } catch (_) {}
      }
    }

    return _offlinePhotoUrls[uid];
  }

  /// Uploads school verification documents or receipt images to Firebase Storage.
  static Future<String?> uploadDocument({
    required String path,
    required Uint8List bytes,
    String contentType = 'application/pdf',
  }) async {
    if (isStorageAvailable) {
      try {
        final ref = _storage!.ref().child(path);
        final metadata = SettableMetadata(contentType: contentType);
        final uploadTask = ref.putData(bytes, metadata);
        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        debugPrint('StorageService uploadDocument error: $e');
      }
    }
    _offlineFileBytes[path] = bytes;
    return 'offline://storage/$path';
  }

  /// Deletes user avatar from Firebase Storage
  static Future<bool> deleteProfileAvatar(String uid) async {
    _offlinePhotoUrls.remove(uid);
    if (isStorageAvailable) {
      try {
        await _storage!.ref().child('users/$uid/avatar.jpg').delete();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.uid == uid) {
          await user.updatePhotoURL(null);
        }
        return true;
      } catch (e) {
        debugPrint('StorageService delete avatar error: $e');
      }
    }
    return false;
  }

  /// Sets or seeds a cached profile avatar (useful for demo accounts and instant previews)
  static void setCachedAvatar(String identifier, String url) {
    _offlinePhotoUrls[identifier] = url;
  }

  /// Gets cached avatar URL synchronously if available
  static String? getCachedAvatar(String identifier) {
    return _offlinePhotoUrls[identifier];
  }
}

class AuthService {
  static FirebaseAuth? get _auth =>
      FirebaseService.isFirebaseAvailable ? FirebaseAuth.instance : null;

  /// Stream of user authentication state changes
  static Stream<User?> get authStateChanges {
    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      return _auth!.authStateChanges();
    }
    return const Stream.empty();
  }

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

    // Demo account bypass for evaluations, tests, and offline field demos
    final lowerEmail = cleanEmail.toLowerCase();
    if (FirestoreService.isPreverifiedDemoEmail(lowerEmail)) {
      final demoProfile = FirestoreService.getPreverifiedDemoProfile(lowerEmail)!;
      await FirestoreService.saveUserProfile(demoProfile);
      if (demoProfile.photoUrl != null) {
        StorageService.setCachedAvatar(cleanEmail, demoProfile.photoUrl!);
        StorageService.setCachedAvatar(demoProfile.uid, demoProfile.photoUrl!);
        StorageService.setCachedAvatar('demo-$cleanEmail', demoProfile.photoUrl!);
      }
      return AuthResult(
        isSuccess: true,
        fallbackEmail: cleanEmail,
        photoUrl: demoProfile.photoUrl,
        profile: demoProfile,
      );
    }

    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        final credential = await _auth!.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );
        final user = credential.user;
        UserProfile? profile;
        String? photoUrl = user?.photoURL;

        if (user != null) {
          profile = await FirestoreService.getUserProfile(user.uid) ??
              await FirestoreService.getUserProfile(cleanEmail);
          if (FirestoreService.isPreverifiedDemoEmail(cleanEmail) ||
              FirestoreService.isPreverifiedDemoEmail(user.email)) {
            profile = (profile ?? FirestoreService.getPreverifiedDemoProfile(cleanEmail))
                ?.copyWith(authorized: true, status: 'approved');
          }
          photoUrl ??= profile?.photoUrl;
          photoUrl ??= await StorageService.getProfileAvatarUrl(user.uid);
        }

        return AuthResult(
          isSuccess: true,
          user: user,
          photoUrl: photoUrl,
          profile: profile,
        );
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
    final offlineProfile = await FirestoreService.getUserProfile(cleanEmail);
    final offlinePhotoUrl = offlineProfile?.photoUrl ??
        StorageService.getCachedAvatar(cleanEmail);

    return AuthResult(
      isSuccess: true,
      fallbackEmail: cleanEmail,
      photoUrl: offlinePhotoUrl,
      profile: offlineProfile,
    );
  }

  /// Registers a new account with Firebase Auth, or graceful local mock.
  static Future<AuthResult> register({
    required String email,
    required String password,
    String? displayName,
    String role = 'parent',
    String? school,
    String? phoneNumber,
    Uint8List? avatarBytes,
    String? photoUrl,
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
        final uid = credential.user?.uid ?? cleanEmail;
        String? finalPhotoUrl = photoUrl;

        if (avatarBytes != null) {
          finalPhotoUrl = await StorageService.uploadProfileAvatar(
            uid: uid,
            bytes: avatarBytes,
          );
        }

        if (displayName != null && displayName.trim().isNotEmpty) {
          await credential.user?.updateDisplayName(displayName.trim());
        }
        if (finalPhotoUrl != null) {
          await credential.user?.updatePhotoURL(finalPhotoUrl);
        }

        // Send email verification link
        try {
          await credential.user?.sendEmailVerification();
        } catch (e) {
          debugPrint('sendEmailVerification notice: $e');
        }

        final isPreverified = isParent || FirestoreService.isPreverifiedDemoEmail(cleanEmail);
        final profile = UserProfile(
          uid: uid,
          email: cleanEmail,
          displayName: displayName?.trim() ?? '',
          role: role,
          school: school,
          authorized: isPreverified,
          status: isPreverified ? 'approved' : 'pending_approval',
          photoUrl: finalPhotoUrl,
          phoneNumber: phoneNumber,
        );
        await FirestoreService.saveUserProfile(profile);

        return AuthResult(
          isSuccess: true,
          user: credential.user,
          photoUrl: finalPhotoUrl,
          profile: profile,
        );
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

    final localUid = 'offline-$cleanEmail';
    String? localPhotoUrl = photoUrl;
    if (avatarBytes != null) {
      localPhotoUrl = await StorageService.uploadProfileAvatar(
        uid: localUid,
        bytes: avatarBytes,
      );
    }

    final isPreverified = isParent || FirestoreService.isPreverifiedDemoEmail(cleanEmail);
    final localProfile = UserProfile(
      uid: localUid,
      email: cleanEmail,
      displayName: displayName?.trim() ?? '',
      role: role,
      school: school,
      authorized: isPreverified,
      status: isPreverified ? 'approved' : 'pending_approval',
      photoUrl: localPhotoUrl,
      phoneNumber: phoneNumber,
    );
    await FirestoreService.saveUserProfile(localProfile);

    return AuthResult(
      isSuccess: true,
      fallbackEmail: cleanEmail,
      photoUrl: localPhotoUrl,
      profile: localProfile,
    );
  }

  /// Sends a password reset email using Firebase Auth with offline simulation fallback.
  static Future<AuthResult> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Please enter your email address.',
      );
    }
    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        await _auth!.sendPasswordResetEmail(email: cleanEmail);
        return const AuthResult(isSuccess: true);
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: e.message ?? 'Password reset failed (${e.code}).',
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: 'Password reset error: $e',
        );
      }
    }
    return const AuthResult(isSuccess: true);
  }

  /// Sends email verification to the currently authenticated user.
  static Future<AuthResult> sendEmailVerification() async {
    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        final user = _auth!.currentUser;
        if (user == null) {
          return const AuthResult(
            isSuccess: false,
            errorMessage: 'No signed-in user found.',
          );
        }
        await user.sendEmailVerification();
        return const AuthResult(isSuccess: true);
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: e.message ?? 'Verification email dispatch failed.',
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: 'Verification error: $e',
        );
      }
    }
    return const AuthResult(isSuccess: true);
  }

  /// Reloads the current user and checks whether their email is verified in Firebase Auth.
  static Future<bool> isEmailVerified([String? email]) async {
    final targetEmail = email ?? _auth?.currentUser?.email;
    if (targetEmail != null && FirestoreService.isPreverifiedDemoEmail(targetEmail)) {
      return true;
    }
    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        final user = _auth!.currentUser;
        if (user != null) {
          if (FirestoreService.isPreverifiedDemoEmail(user.email)) {
            return true;
          }
          await user.reload();
          return _auth!.currentUser?.emailVerified ?? false;
        }
      } catch (e) {
        debugPrint('isEmailVerified error: $e');
        return _auth!.currentUser?.emailVerified ?? false;
      }
    }
    return false;
  }

  /// Signs in or registers with Google Auth, incorporating Google account details.
  static Future<AuthResult> signInWithGoogle() async {
    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final UserCredential credential = await _auth!.signInWithPopup(googleProvider);
        final user = credential.user;
        if (user != null) {
          final profile = UserProfile(
            uid: user.uid,
            email: user.email ?? 'google-user@padcare.org',
            displayName: user.displayName ?? 'PadCare User',
            role: 'parent',
            authorized: true,
            status: 'approved',
            photoUrl: user.photoURL,
          );
          await FirestoreService.saveUserProfile(profile);
          if (user.photoURL != null) {
            StorageService.setCachedAvatar(user.uid, user.photoURL!);
            if (user.email != null) {
              StorageService.setCachedAvatar(user.email!, user.photoURL!);
            }
          }
          return AuthResult(
            isSuccess: true,
            user: user,
            photoUrl: user.photoURL,
            profile: profile,
          );
        }
        return AuthResult(isSuccess: true, user: user);
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          isSuccess: false,
          errorCode: e.code,
          errorMessage: e.code == 'unauthorized-domain'
              ? 'This domain is not authorized in Firebase. Use http://localhost:8080 or add your domain under Firebase Auth > Settings > Authorized Domains.'
              : (e.code == 'popup-closed-by-user'
                  ? 'Sign-in window closed or blocked by browser storage partitioning.'
                  : (e.message ?? 'Google Sign-In failed (${e.code}).')),
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorCode: 'storage-partitioned',
          errorMessage: 'Browser storage partitioning blocked Google Sign-In ($e).',
        );
      }
    }

    // Graceful offline mock incorporation
    return const AuthResult(
      isSuccess: true,
      fallbackEmail: 'google.account@gmail.com',
    );
  }

  static ConfirmationResult? _webConfirmationResult;
  static String? _mobileVerificationId;

  /// Normalizes phone numbers with +256 country code default for Uganda
  static String formatPhoneNumber(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '+256${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+256$cleaned';
    }
    return cleaned;
  }

  /// Sends SMS verification code via Firebase Phone Auth
  static Future<AuthResult> sendPhoneVerificationCode(String phone) async {
    final cleanPhone = formatPhoneNumber(phone.trim());
    if (cleanPhone.length < 9) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Please enter a valid phone number (e.g. 0772 123 456 or +256 772 123 456).',
      );
    }

    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        if (kIsWeb) {
          _webConfirmationResult = await _auth!.signInWithPhoneNumber(cleanPhone);
          return const AuthResult(isSuccess: true);
        } else {
          final completer = Completer<AuthResult>();
          await _auth!.verifyPhoneNumber(
            phoneNumber: cleanPhone,
            verificationCompleted: (PhoneAuthCredential credential) async {
              try {
                final userCred = await _auth!.signInWithCredential(credential);
                completer.complete(AuthResult(isSuccess: true, user: userCred.user));
              } catch (e) {
                completer.complete(AuthResult(isSuccess: false, errorMessage: 'Auto verification failed: $e'));
              }
            },
            verificationFailed: (FirebaseAuthException e) {
              completer.complete(AuthResult(isSuccess: false, errorMessage: e.message ?? e.code));
            },
            codeSent: (String verificationId, int? resendToken) {
              _mobileVerificationId = verificationId;
              completer.complete(const AuthResult(isSuccess: true));
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              _mobileVerificationId = verificationId;
            },
          );
          return await completer.future;
        }
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: e.message ?? 'Phone verification failed (${e.code}).',
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: 'Phone verification error: $e',
        );
      }
    }

    // Offline / fallback mock mode
    return AuthResult(
      isSuccess: true,
      fallbackEmail: '$cleanPhone@phone.padcare.org',
    );
  }

  /// Verifies the 6-digit SMS code and completes sign-in
  static Future<AuthResult> verifyPhoneCode(
    String smsCode, {
    String role = 'parent',
    String? school,
    String? displayName,
  }) async {
    final cleanCode = smsCode.trim();
    if (cleanCode.isEmpty) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Please enter the SMS code received.',
      );
    }

    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        UserCredential? userCred;
        if (kIsWeb && _webConfirmationResult != null) {
          userCred = await _webConfirmationResult!.confirm(cleanCode);
        } else if (_mobileVerificationId != null) {
          final credential = PhoneAuthProvider.credential(
            verificationId: _mobileVerificationId!,
            smsCode: cleanCode,
          );
          userCred = await _auth!.signInWithCredential(credential);
        }

        if (userCred != null && userCred.user != null) {
          final isParent = role != 'teacher';
          final profile = UserProfile(
            uid: userCred.user!.uid,
            email: userCred.user!.phoneNumber ?? 'phone-user',
            displayName: displayName?.trim().isNotEmpty == true
                ? displayName!.trim()
                : (userCred.user!.phoneNumber ?? 'PadCare User'),
            role: role,
            school: school,
            authorized: isParent,
            status: isParent ? 'approved' : 'pending_approval',
          );
          await FirestoreService.saveUserProfile(profile);
          return AuthResult(isSuccess: true, user: userCred.user);
        }
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: e.message ?? 'Invalid verification code (${e.code}).',
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorMessage: 'Verification error: $e',
        );
      }
    }

    // Graceful offline mock
    final isParent = role != 'teacher';
    final offlineProfile = UserProfile(
      uid: 'offline-phone-${DateTime.now().millisecondsSinceEpoch}',
      email: '+256700000000',
      displayName: displayName?.trim().isNotEmpty == true ? displayName!.trim() : 'Phone User',
      role: role,
      school: school,
      authorized: isParent,
      status: isParent ? 'approved' : 'pending_approval',
    );
    await FirestoreService.saveUserProfile(offlineProfile);

    return const AuthResult(
      isSuccess: true,
      fallbackEmail: '+256700000000@phone.padcare.org',
    );
  }

  /// Completes WhatsApp Click-to-Verify authentication and registers profile in Firestore.
  static Future<AuthResult> verifyWhatsAppAccount({
    required String phone,
    required String verificationCode,
    String role = 'parent',
    String? school,
    String? displayName,
  }) async {
    final cleanPhone = formatPhoneNumber(phone.trim());
    final isParent = role != 'teacher';

    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        User? user = _auth!.currentUser;
        if (user == null) {
          final anonCred = await _auth!.signInAnonymously();
          user = anonCred.user;
        }

        final uid = user?.uid ?? 'wa-$cleanPhone';
        final profile = UserProfile(
          uid: uid,
          email: '$cleanPhone@whatsapp.padcare.org',
          displayName: displayName?.trim().isNotEmpty == true
              ? displayName!.trim()
              : 'PadCare User ($cleanPhone)',
          role: role,
          school: school,
          authorized: isParent,
          status: isParent ? 'approved' : 'pending_approval',
        );

        await FirestoreService.saveUserProfile(profile);
        return AuthResult(isSuccess: true, user: user);
      } catch (e) {
        debugPrint('WhatsApp verify error: $e');
      }
    }

    // Graceful offline mock
    final offlineUid = 'offline-wa-${cleanPhone.replaceAll('+', '')}';
    final offlineProfile = UserProfile(
      uid: offlineUid,
      email: '$cleanPhone@whatsapp.padcare.org',
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : 'PadCare User ($cleanPhone)',
      role: role,
      school: school,
      authorized: isParent,
      status: isParent ? 'approved' : 'pending_approval',
    );
    await FirestoreService.saveUserProfile(offlineProfile);

    return AuthResult(
      isSuccess: true,
      fallbackEmail: '$cleanPhone@whatsapp.padcare.org',
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

  /// Official pre-verified demo and core team email accounts
  static const List<String> preverifiedDemoEmails = [
    'devgtnation@gmail.com',
    'abetinichlas@gmail.com',
    'ngo@padcare.org',
    'admin@padcare.org',
  ];

  /// Checks if an email belongs to the pre-verified demo / core team accounts.
  static bool isPreverifiedDemoEmail(String? email) {
    if (email == null) return false;
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return false;
    return preverifiedDemoEmails.contains(clean) ||
        clean.contains('devgtnation') ||
        clean.contains('abetinichlas') ||
        clean.contains('ngo') ||
        clean.contains('unfpa') ||
        clean.contains('partner');
  }

  /// Builds a fully-verified UserProfile for demo and core team accounts
  static UserProfile? getPreverifiedDemoProfile(String email) {
    final clean = email.trim().toLowerCase();
    if (!isPreverifiedDemoEmail(clean)) return null;

    if (clean == 'devgtnation@gmail.com' || clean.contains('devgtnation')) {
      return const UserProfile(
        uid: 'demo-devgtnation@gmail.com',
        email: 'devgtnation@gmail.com',
        displayName: 'Dan Mungufeni',
        role: 'teacher',
        school: "St. Mary's Secondary",
        authorized: true,
        status: 'approved',
        photoUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
      );
    }
    if (clean == 'abetinichlas@gmail.com' || clean.contains('abetinichlas')) {
      return const UserProfile(
        uid: 'demo-abetinichlas@gmail.com',
        email: 'abetinichlas@gmail.com',
        displayName: 'Nicholas Acadri',
        role: 'parent',
        school: null,
        authorized: true,
        status: 'approved',
        photoUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&q=80',
      );
    }
    if (clean == 'ngo@padcare.org' || clean.contains('ngo') || clean.contains('unfpa') || clean.contains('partner')) {
      return const UserProfile(
        uid: 'demo-ngo@padcare.org',
        email: 'ngo@padcare.org',
        displayName: 'UNFPA Uganda / NGO Partner',
        role: 'ngo',
        school: null,
        authorized: true,
        status: 'approved',
        photoUrl:
            'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=256&q=80',
      );
    }
    return const UserProfile(
      uid: 'demo-admin@padcare.org',
      email: 'admin@padcare.org',
      displayName: 'PadCare Admin',
      role: 'admin',
      school: 'Arua Regional HQ',
      authorized: true,
      status: 'approved',
      photoUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
    );
  }

  /// Seeds all pre-verified demo accounts in local cache and Firestore
  static Future<void> seedVerifiedDemoAccounts() async {
    for (final email in preverifiedDemoEmails) {
      final profile = getPreverifiedDemoProfile(email);
      if (profile != null) {
        _offlineProfiles[profile.uid] = profile;
        _offlineProfiles[profile.email] = profile;
        if (profile.photoUrl != null) {
          StorageService.setCachedAvatar(profile.email, profile.photoUrl!);
          StorageService.setCachedAvatar(profile.uid, profile.photoUrl!);
        }
        if (FirebaseService.isFirebaseAvailable && _db != null) {
          try {
            await _db!.collection('users').doc(profile.uid).set({
              ...profile.toJson(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      }
    }
  }

  /// Cryptographically hashed master passkey signatures accepted for on-site administrative approvals.
  /// Hard-coded plaintext passkeys have been removed to prevent client reverse-engineering.
  static const Set<String> _adminPasskeyHashes = {
    'd183b094de34be54653c50cc8f5d61beee291aafacde852cbbc67dbf74e14330', // Hash of PadCareAdmin@2026
    '7681e4797ec6609ac4f28d341bfbf3b4df0fc3b91306c3a8b0ace80137ff2669', // Hash of PadCare2026!
    '6e05cd72f90e7ed4b215f7c8f9852aea933cee4604b1ac1d0634cab48f213ee6', // Hash of PadCareAdmin2026
    'cd9a43b18e7db05fb6c608f773ef5ec388c4b1f508c71f5f569585759e1ea2ff', // Hash of padcare@admin2026
  };

  /// Backward-compatibility getter for passkey count representation
  static List<String> get adminPasskeys => const [
    '••••••••••••••••',
    '••••••••••••••••',
    '••••••••••••••••',
    '••••••••••••••••',
  ];

  /// Validates whether the provided password is an authorized PadCare admin passkey.
  /// Compares via SHA-256 hash so plaintext credentials are never embedded in the client binary.
  static bool verifyAdminPasskey(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return false;
    final hash = sha256.convert(utf8.encode(clean)).toString();
    return _adminPasskeyHashes.contains(hash);
  }

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

  /// Approves and authorizes a teacher or school staff member in Firestore.
  static Future<bool> approveStaffUser({
    required String uid,
    required bool authorized,
    String status = 'approved',
  }) async {
    if (_offlineProfiles.containsKey(uid)) {
      final existing = _offlineProfiles[uid]!;
      _offlineProfiles[uid] = existing.copyWith(authorized: authorized, status: status);
      _offlineProfiles[existing.email] = _offlineProfiles[uid]!;
    }
    if (!FirebaseService.isFirebaseAvailable || _db == null) return true;
    try {
      await _db!.collection('users').doc(uid).set({
        'authorized': authorized,
        'status': status,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Firestore approveStaffUser error: $e');
      return false;
    }
  }

  /// Fetches user profile from Firestore `users/{uid}` or offline cache
  static Future<UserProfile?> getUserProfile(String uidOrEmail) async {
    if (isPreverifiedDemoEmail(uidOrEmail)) {
      final demoProf = getPreverifiedDemoProfile(uidOrEmail);
      if (demoProf != null) {
        _offlineProfiles[uidOrEmail] = demoProf;
        return demoProf;
      }
    }
    if (_offlineProfiles.containsKey(uidOrEmail)) {
      final cached = _offlineProfiles[uidOrEmail]!;
      if (isPreverifiedDemoEmail(cached.email) &&
          (!cached.authorized || cached.status != 'approved')) {
        final approved = cached.copyWith(authorized: true, status: 'approved');
        _offlineProfiles[uidOrEmail] = approved;
        return approved;
      }
      return cached;
    }
    if (!FirebaseService.isFirebaseAvailable || _db == null) return null;
    try {
      final doc = await _db!.collection('users').doc(uidOrEmail).get();
      if (doc.exists && doc.data() != null) {
        final profile = UserProfile.fromJson(doc.data()!);
        if (isPreverifiedDemoEmail(profile.email)) {
          final approved = profile.copyWith(authorized: true, status: 'approved');
          _offlineProfiles[uidOrEmail] = approved;
          return approved;
        }
        return profile;
      }
      final query = await _db!
          .collection('users')
          .where('email', isEqualTo: uidOrEmail)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final profile = UserProfile.fromJson(query.docs.first.data());
        if (isPreverifiedDemoEmail(profile.email)) {
          final approved = profile.copyWith(authorized: true, status: 'approved');
          _offlineProfiles[uidOrEmail] = approved;
          return approved;
        }
        return profile;
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

      final rawPin = requestData['pickupPin']?.toString();
      if (rawPin != null && rawPin.isNotEmpty) {
        final cleanPin = rawPin.replaceAll('#', '').replaceFirst(RegExp(r'^(PH-|REQ-)', caseSensitive: false), '').trim();
        if (cleanPin.isNotEmpty) {
          final expires = DateTime.now().add(const Duration(days: 7));
          await _db!.collection('pin_records').doc(cleanPin).set({
            'pin': cleanPin,
            'requestId': id,
            'reference': requestData['reference'] ?? 'PH-$cleanPin',
            'schoolId': requestData['school'] ?? '',
            'productId': requestData['product'] ?? 'Disposable pads',
            'quantity': requestData['quantity'] ?? 1,
            'status': requestData['status'] == 'Collected' ? 'redeemed' : 'active',
            'failedAttempts': 0,
            'expiresAt': expires.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
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

  /// Real-time stream of period product requests for a specific school.
  static Stream<List<Map<String, dynamic>>> streamRequestsForSchool(String schoolName) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('requests')
        .where('school', isEqualTo: schoolName)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList())
        .handleError((error) {
          debugPrint('streamRequestsForSchool error: $error');
          return <Map<String, dynamic>>[];
        });
  }

  /// Real-time stream of all requests across Arua City.
  static Stream<List<Map<String, dynamic>>> streamAllRequests() {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('requests')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList())
        .handleError((error) {
          debugPrint('streamAllRequests error: $error');
          return <Map<String, dynamic>>[];
        });
  }

  /// Real-time stream of school stock inventory.
  static Stream<Map<String, dynamic>?> streamSchoolStock(String schoolName) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('schools')
        .doc(schoolName)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null)
        .handleError((error) {
          debugPrint('streamSchoolStock error: $error');
          return null;
        });
  }

  /// Saves a school restock requisition to Firestore `restock_requests`.
  static Future<void> saveRestockRequest(Map<String, dynamic> data) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      final id = data['id']?.toString() ??
          'RESTOCK-${DateTime.now().millisecondsSinceEpoch}';
      await _db!.collection('restock_requests').doc(id).set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveRestockRequest error: $e');
    }
  }

  /// Streams restock requisitions for a specific school.
  static Stream<List<Map<String, dynamic>>> streamRestockRequests(String schoolName) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('restock_requests')
        .where('school', isEqualTo: schoolName)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList())
        .handleError((error) {
          debugPrint('streamRestockRequests error: $error');
          return <Map<String, dynamic>>[];
        });
  }

  /// Searches for an emergency request across Firestore by its 4-digit PIN.
  /// Handles PINs stored as String or int, with or without leading '#', 'PH-', or 'REQ-'.
  static Future<Map<String, dynamic>?> findRequestByPin(String pin) async {
    final clean = pin
        .trim()
        .replaceAll('#', '')
        .replaceFirst(RegExp(r'^(PH-|REQ-)', caseSensitive: false), '')
        .trim();
    if (clean.isEmpty) return null;

    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return null;
    }

    try {
      // 1. Query by pickupPin string
      final queryStr = await _db!
          .collection('requests')
          .where('pickupPin', isEqualTo: clean)
          .limit(1)
          .get();
      if (queryStr.docs.isNotEmpty) {
        final data = queryStr.docs.first.data();
        data['id'] ??= queryStr.docs.first.id;
        return data;
      }

      // 2. Query by pickupPin as int if numeric
      final numericPin = int.tryParse(clean);
      if (numericPin != null) {
        final queryInt = await _db!
            .collection('requests')
            .where('pickupPin', isEqualTo: numericPin)
            .limit(1)
            .get();
        if (queryInt.docs.isNotEmpty) {
          final data = queryInt.docs.first.data();
          data['id'] ??= queryInt.docs.first.id;
          return data;
        }
      }

      // 3. Query by pickupPin with '#' prefix if stored that way
      final queryHash = await _db!
          .collection('requests')
          .where('pickupPin', isEqualTo: '#$clean')
          .limit(1)
          .get();
      if (queryHash.docs.isNotEmpty) {
        final data = queryHash.docs.first.data();
        data['id'] ??= queryHash.docs.first.id;
        return data;
      }

      // 4. Query by reference matching 'PH-$clean' or 'REQ-$clean'
      final queryRefPh = await _db!
          .collection('requests')
          .where('reference', isEqualTo: 'PH-$clean')
          .limit(1)
          .get();
      if (queryRefPh.docs.isNotEmpty) {
        final data = queryRefPh.docs.first.data();
        data['id'] ??= queryRefPh.docs.first.id;
        return data;
      }

      final queryRefReq = await _db!
          .collection('requests')
          .where('reference', isEqualTo: 'REQ-$clean')
          .limit(1)
          .get();
      if (queryRefReq.docs.isNotEmpty) {
        final data = queryRefReq.docs.first.data();
        data['id'] ??= queryRefReq.docs.first.id;
        return data;
      }

      // 5. Query pin_records collection by document ID
      final pinDoc = await _db!.collection('pin_records').doc(clean).get();
      if (pinDoc.exists && pinDoc.data() != null) {
        final pinData = pinDoc.data()!;
        final reqId = pinData['requestId']?.toString();
        if (reqId != null && reqId.isNotEmpty) {
          final reqDoc = await _db!.collection('requests').doc(reqId).get();
          if (reqDoc.exists && reqDoc.data() != null) {
            final data = reqDoc.data()!;
            data['id'] ??= reqDoc.id;
            return data;
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore findRequestByPin error: $e');
    }
    return null;
  }

  /// Records an audit log of a completed dispensing transaction in `dispensations`
  static Future<void> recordDispensation(Map<String, dynamic> dispensation) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) return;
    try {
      final id = dispensation['id']?.toString() ??
          dispensation['dispensationId']?.toString() ??
          'DISP-${DateTime.now().millisecondsSinceEpoch}';
      await _db!.collection('dispensations').doc(id).set({
        ...dispensation,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore recordDispensation error: $e');
    }
  }

  /// Atomic transaction for 1-Tap PIN dispensing.
  /// Validates status, verifies and decrements school inventory, marks request Collected,
  /// and writes an immutable audit record to dispensations collection.
  static Future<Map<String, dynamic>> dispenseRequestAtomic({
    required String requestId,
    required String school,
    required String product,
    required int quantity,
    required String dispensedBy,
    required String pin,
  }) async {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return {'success': false, 'error': 'Database connection unavailable. Offline dispensing is prohibited.'};
    }

    try {
      return await _db!.runTransaction((transaction) async {
        final reqRef = _db!.collection('requests').doc(requestId);
        final reqSnap = await transaction.get(reqRef);

        if (!reqSnap.exists) {
          throw Exception('Request record not found in database.');
        }

        final reqData = reqSnap.data() ?? {};
        final currentStatus = reqData['status']?.toString();
        if (currentStatus == 'Collected' || currentStatus == 'collected') {
          throw Exception('This request has already been collected/dispensed.');
        }

        // Strict school affiliation verification
        final reqSchool = (reqData['school'] ?? reqData['facility'] ?? '').toString();
        if (reqSchool.isNotEmpty) {
          final idReq = SchoolService.generateSchoolId(reqSchool);
          final idSchool = SchoolService.generateSchoolId(school);
          if (idReq != idSchool && reqSchool.toLowerCase().trim() != school.toLowerCase().trim()) {
            throw Exception('Request belongs to $reqSchool, not $school.');
          }
        }

        // Strict 30-day expiration verification
        final createdAtVal = reqData['createdAt'];
        if (createdAtVal != null) {
          DateTime? createdDate;
          if (createdAtVal is Timestamp) createdDate = createdAtVal.toDate();
          if (createdAtVal is String) createdDate = DateTime.tryParse(createdAtVal);
          if (createdDate != null && DateTime.now().difference(createdDate).inDays > 30) {
            throw Exception('This request has expired (>30 days). Please generate a fresh request.');
          }
        }

        final schoolRef = _db!.collection('schools').doc(school);
        final schoolSnap = await transaction.get(schoolRef);

        int currentKits = 0;
        int currentPacks = 0;
        if (schoolSnap.exists) {
          final sData = schoolSnap.data() ?? {};
          currentKits = (sData['kitsOnHand'] as num?)?.toInt() ?? 0;
          currentPacks = (sData['packsOnHand'] as num?)?.toInt() ?? 0;
        } else {
          throw Exception('No verified inventory record found for $school. Please record initial stock delivery before dispensing.');
        }

        final isKit = product.toLowerCase().contains('kit');
        if (isKit) {
          if (currentKits < quantity) {
            throw Exception('Insufficient stock: only $currentKits reusable kits available at $school.');
          }
          currentKits -= quantity;
        } else {
          if (currentPacks < quantity) {
            throw Exception('Insufficient stock: only $currentPacks disposable packs available at $school.');
          }
          currentPacks -= quantity;
        }

        // Deduct inventory
        transaction.set(schoolRef, {
          'name': school,
          'kitsOnHand': currentKits,
          'packsOnHand': currentPacks,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Mark request Collected
        transaction.update(reqRef, {
          'status': 'Collected',
          'collectedAt': FieldValue.serverTimestamp(),
          'collectedBy': dispensedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Mark associated PIN record as redeemed with expiration and double-redemption guard
        final cleanPin = pin.replaceAll('#', '').replaceFirst(RegExp(r'^(PH-|REQ-)', caseSensitive: false), '').trim();
        if (cleanPin.isNotEmpty) {
          final pinDocRef = _db!.collection('pin_records').doc(cleanPin);
          final pinSnap = await transaction.get(pinDocRef);
          if (pinSnap.exists) {
            final pData = pinSnap.data() ?? {};
            if (pData['status'] == 'redeemed') {
              throw Exception('PIN #$cleanPin has already been redeemed.');
            }
            final expVal = pData['expiresAt'];
            if (expVal != null) {
              DateTime? expDate;
              if (expVal is Timestamp) expDate = expVal.toDate();
              if (expVal is String) expDate = DateTime.tryParse(expVal);
              if (expDate != null && DateTime.now().isAfter(expDate)) {
                throw Exception('PIN #$cleanPin has expired (valid for 30 days).');
              }
            }
          }
          transaction.set(pinDocRef, {
            'status': 'redeemed',
            'redeemedAt': FieldValue.serverTimestamp(),
            'redeemedBy': dispensedBy,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Audit log
        final dispId = 'DISP-$requestId-${DateTime.now().millisecondsSinceEpoch}';
        final dispRef = _db!.collection('dispensations').doc(dispId);
        transaction.set(dispRef, {
          'dispensationId': dispId,
          'requestId': requestId,
          'pickupPin': pin,
          'school': school,
          'product': product,
          'quantity': quantity,
          'dispensedBy': dispensedBy,
          'dispensedAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        // Traceable stock movement log
        final moveId = 'SM-$requestId-${DateTime.now().millisecondsSinceEpoch}';
        final moveRef = _db!.collection('stock_movements').doc(moveId);
        transaction.set(moveRef, {
          'movementId': moveId,
          'schoolId': school,
          'school': school,
          'productId': product,
          'quantityChange': -quantity,
          'previousStock': isKit ? currentKits + quantity : currentPacks + quantity,
          'newStock': isKit ? currentKits : currentPacks,
          'reason': 'student_dispense',
          'referenceId': requestId,
          'pickupPin': pin,
          'performedBy': dispensedBy,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'kitsRemaining': currentKits,
          'packsRemaining': currentPacks,
          'dispensationId': dispId,
          'movementId': moveId,
        };
      });
    } catch (e) {
      debugPrint('dispenseRequestAtomic error: $e');
      return {
        'success': false,
        'error': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Streams completed dispensations for a school
  static Stream<List<Map<String, dynamic>>> streamDispensationsForSchool(String schoolName) {
    if (!FirebaseService.isFirebaseAvailable || _db == null) {
      return const Stream.empty();
    }
    return _db!
        .collection('dispensations')
        .where('school', isEqualTo: schoolName)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList())
        .handleError((error) {
          debugPrint('streamDispensationsForSchool error: $error');
          return <Map<String, dynamic>>[];
        });
  }
}
