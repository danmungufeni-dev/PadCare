# PadCare Firebase Integration (Android)

PadCare uses Firebase Authentication, Cloud Firestore, and Firebase Storage. The app's Firebase service layer keeps the existing UI and offline/demo fallback, but live production behavior requires the Android app to be registered and the Firebase Console services and rules to be configured.

## Firebase project

The repository currently targets project ID `padcare-73556`. Confirm that this is the project you own before running deployment commands.

## 1. Register/configure the Android app

1. Open the [Firebase Console](https://console.firebase.google.com/) and select `padcare-73556`.
2. Open Project settings → General → Your apps. Confirm an Android app exists with package name `com.padcare.padcare`. If it does not, add it with that exact package name.
3. Download the app's `google-services.json` and place it at `android/app/google-services.json`. Do not rename it.
4. From the PadCare repository root, run:

```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure --project=padcare-73556 --platforms=android
```

Select the existing project and Android app when prompted. Review the generated `lib/firebase_options.dart` and confirm the project ID is `padcare-73556`.

The repository already declares the Firebase Flutter dependencies and Google Services Gradle plugin. The Android package ID is `com.padcare.padcare`.

## 2. Enable sign-in methods

In Firebase Console → Build → Authentication → Sign-in method, enable only the methods you intend to offer:

- **Email/Password** for email registration and sign-in.
- **Phone** if using SMS verification.
- **Google** if the Google sign-in button is shown.
- **Anonymous** only if the app's WhatsApp verification flow needs its anonymous-auth fallback.

For Google sign-in on Android, add the SHA-1 and SHA-256 fingerprints for your debug/release signing certificates in Project settings → Your apps → Android app. Then download a fresh `google-services.json` containing the OAuth client configuration. The app uses the native Google Sign-In flow on Android and the popup flow on web.

For production, remove demo account bypasses from live authentication. The service has been changed so hard-coded demo identities are only accepted when Firebase is unavailable; when Firebase is active, real Firebase credentials are required.

## 3. Create Firestore and deploy rules

1. In Build → Firestore Database, create the database in a region appropriate for your users and operations.
2. Do not leave Firestore in open Test mode.
3. From the repository root, after checking out this integration branch, run:

```bash
firebase login
firebase use padcare-73556
firebase deploy --only firestore:rules,storage --project padcare-73556
```

The rules restrict user profiles, requests, inventory, restock requests, and donation records. Donation documents are readable only by approved staff because legacy records may contain contact details. Teachers must be explicitly approved in the user profile before they can manage inventory. Do not approve a user by letting that user edit their own `authorized` or `status` fields; use a trusted administrative workflow.

## 4. Storage

Storage rules are configured in `storage.rules` and allow signed-in users to upload small image files only to their own `users/{uid}/` folder. This covers profile avatars. Do not upload identity documents, medical details, or other sensitive files until a separate, narrowly scoped storage path and authorization workflow has been designed.

## 5. Donations are pledges, not payment processing

The current Mobile Money screen does not connect to MTN MoMo, Airtel Money, or a card processor and cannot verify payment. It now records a **pending sponsorship pledge** without uploading donor names or phone numbers to the public donations collection. Pending pledges are not included in totals. To mark a pledge as completed, implement a trusted server-side payment callback/verification workflow; never let the mobile client set a donation to `completed`.

## 6. Build and verify the Android APK

Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Install and test the generated APK on a physical Android device with Google Play services where required. Test registration, sign-in, password reset, request creation, location/stock reads, approved-staff stock updates, sign-out, and denied access for unauthorized users.

## Security notes

- Never commit service-account private keys or admin credentials into the Flutter app.
- Firebase client configuration identifies the project; Firestore and Storage rules are the actual data-access boundary.
- If a feature is denied by rules, fix the authorization model rather than opening the database to everyone.
- Review billing, usage limits, App Check, and Firebase launch checklist before production.
