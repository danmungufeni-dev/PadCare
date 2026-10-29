// File generated for PadCare Firebase configuration template.
// To connect your real Firebase project:
// 1. Go to https://console.firebase.google.com/ and create/select your project.
// 2. Add an Android app and Web app.
// 3. Replace the placeholder values below with your credentials, OR run:
//    flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String _placeholder = 'YOUR-FIREBASE-PROJECT-ID';

  /// Helper to check whether real credentials have been supplied.
  static bool get isConfigured {
    return web.projectId != _placeholder &&
        web.apiKey != 'YOUR-WEB-API-KEY' &&
        android.projectId != _placeholder;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR-WEB-API-KEY',
    appId: '1:1234567890:web:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'YOUR-FIREBASE-PROJECT-ID',
    authDomain: 'YOUR-FIREBASE-PROJECT-ID.firebaseapp.com',
    storageBucket: 'YOUR-FIREBASE-PROJECT-ID.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR-ANDROID-API-KEY',
    appId: '1:1234567890:android:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'YOUR-FIREBASE-PROJECT-ID',
    storageBucket: 'YOUR-FIREBASE-PROJECT-ID.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR-IOS-API-KEY',
    appId: '1:1234567890:ios:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'YOUR-FIREBASE-PROJECT-ID',
    storageBucket: 'YOUR-FIREBASE-PROJECT-ID.appspot.com',
    iosBundleId: 'com.padcare.padcare',
  );
}
