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
    appId: '1:527730536648:web:f68878a268bb8203bf35fd',
    messagingSenderId: '527730536648',
    projectId: 'padcare-73556',
    authDomain: 'padcare-73556.firebaseapp.com',
    storageBucket: 'padcare-73556.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR-ANDROID-API-KEY',
    appId: '1:527730536648:android:f68878a268bb8203bf35fd',
    messagingSenderId: '527730536648',
    projectId: 'padcare-73556',
    storageBucket: 'padcare-73556.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR-IOS-API-KEY',
    appId: '1:527730536648:ios:f68878a268bb8203bf35fd',
    messagingSenderId: '527730536648',
    projectId: 'padcare-73556',
    storageBucket: 'padcare-73556.firebasestorage.app',
    iosBundleId: 'com.padcare.padcare',
  );
}
