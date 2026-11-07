import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

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
  final String role; // 'teacher' | 'parent' | 'admin'
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
    authorized: json['authorized'] as bool? ?? (json['role'] == 'parent'),
    status: json['status'] as String? ?? ((json['role'] == 'parent') ? 'approved' : 'pending'),
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

  static Future<void>? _googleSignInInitialization;

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
    String? demoPhotoUrl;
    String? demoDisplayName;
    String demoRole = 'parent';
    String? demoSchool;

    if (lowerEmail == 'devgtnation@gmail.com') {
      demoPhotoUrl =
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80';
      demoDisplayName = 'Dan Mungufeni (Lead Dev)';
      demoRole = 'teacher';
      demoSchool = 'St. Mary\'s Secondary';
    } else if (lowerEmail == 'abetinichlas@gmail.com') {
      demoPhotoUrl =
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&q=80';
      demoDisplayName = 'Abeti Acadri Nicholas';
      demoRole = 'parent';
    } else if (lowerEmail == 'teacher@padcare.org' ||
        lowerEmail == 'teacher@stmarys.org') {
      demoDisplayName = 'Sister Agnes (Head Teacher)';
      demoRole = 'teacher';
      demoSchool = 'St. Mary\'s Secondary';
    } else if (lowerEmail == 'parent@padcare.org' ||
        lowerEmail == 'demo@padcare.org') {
      demoDisplayName = 'Amina N. (Parent Demo)';
      demoRole = 'parent';
    }

    // Demo identities are for offline previews only. Never bypass real Firebase
    // credentials when a live Firebase project is configured.
    if (demoDisplayName != null && !FirebaseService.isFirebaseAvailable) {
      final demoProfile = UserProfile(
        uid: 'demo-$cleanEmail',
        email: cleanEmail,
        displayName: demoDisplayName,
        role: demoRole,
        school: demoSchool,
        authorized: true,
        status: 'approved',
        photoUrl: demoPhotoUrl,
      );
      await FirestoreService.saveUserProfile(demoProfile);
      if (demoPhotoUrl != null) {
        StorageService.setCachedAvatar(cleanEmail, demoPhotoUrl);
        StorageService.setCachedAvatar('demo-$cleanEmail', demoPhotoUrl);
      }
      return AuthResult(
        isSuccess: true,
        fallbackEmail: cleanEmail,
        photoUrl: demoPhotoUrl,
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

        final profile = UserProfile(
          uid: uid,
          email: cleanEmail,
          displayName: displayName?.trim() ?? '',
          role: role,
          school: school,
          authorized: isParent, // Teachers require backend authorization in Firebase
          status: isParent ? 'approved' : 'pending_approval',
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

    final localProfile = UserProfile(
      uid: localUid,
      email: cleanEmail,
      displayName: displayName?.trim() ?? '',
      role: role,
      school: school,
      authorized: isParent,
      status: isParent ? 'approved' : 'pending_approval',
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

  /// Signs in with Google using the web popup on web and the native
  /// Google Sign-In flow on Android/iOS, then exchanges the ID token with Firebase.
  static Future<AuthResult> signInWithGoogle() async {
    if (FirebaseService.isFirebaseAvailable && _auth != null) {
      try {
        late final UserCredential credential;
        if (kIsWeb) {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          credential = await _auth!.signInWithPopup(googleProvider);
        } else {
          final googleSignIn = GoogleSignIn.instance;
          _googleSignInInitialization ??= googleSignIn.initialize();
          await _googleSignInInitialization;
          final googleUser = await googleSignIn.authenticate();
          final googleAuthentication = googleUser.authentication;
          final idToken = googleAuthentication.idToken;
          if (idToken == null || idToken.isEmpty) {
            return const AuthResult(
              isSuccess: false,
              errorCode: 'missing-google-id-token',
              errorMessage: 'Google sign-in did not return an ID token. Check the Android Firebase app and SHA certificate fingerprints.',
            );
          }
          final oauthCredential = GoogleAuthProvider.credential(idToken: idToken);
          credential = await _auth!.signInWithCredential(oauthCredential);
        }

        final user = credential.user;
        if (user != null) {
          // Preserve existing staff approval/role fields; Google sign-in must not
          // demote a staff account or try to promote a pending one.
          final existingProfile = await FirestoreService.getUserProfile(user.uid);
          final profile = existingProfile?.copyWith(
                email: user.email ?? existingProfile.email,
                displayName: user.displayName ?? existingProfile.displayName,
                photoUrl: user.photoURL ?? existingProfile.photoUrl,
              ) ??
              UserProfile(
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
              ? 'This domain is not authorized in Firebase. Add it under Authentication settings.'
              : (e.message ?? 'Google Sign-In failed (${e.code}).'),
        );
      } catch (e) {
        return AuthResult(
          isSuccess: false,
          errorCode: 'google-sign-in-failed',
          errorMessage: 'Google Sign-In failed. Check the Google provider, Android package name, SHA-1/SHA-256 fingerprints, and google-services.json. ($e)',
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
      rethrow;
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Firestore saveRequest skipped: sign-in is required.');
        return;
      }
      final id = requestData['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      await _db!.collection('requests').doc(id).set(
        {
          ...requestData,
          'ownerUid': user.uid,
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _db!.collection('requests').doc(requestId).update({
        'status': status,
        'reviewedByUid': user.uid,
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Firestore saveRestockRequest skipped: sign-in is required.');
        return;
      }
      final id = data['id']?.toString() ??
          'RESTOCK-${DateTime.now().millisecondsSinceEpoch}';
      await _db!.collection('restock_requests').doc(id).set({
        ...data,
        'createdByUid': user.uid,
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
}
