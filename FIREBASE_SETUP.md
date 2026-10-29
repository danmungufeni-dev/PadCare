# PadCare Firebase Integration Guide

PadCare is now integrated with **Firebase Authentication** and **Cloud Firestore**!

The app includes **graceful offline fallback**: it will function completely in demo/offline mode until you link your Firebase project credentials.

---

## How to Link Your Firebase Project

### Method 1: Quick Configuration (Manual Keys)
1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a project (e.g. `padcare-app`).
2. **Enable Authentication**:
   * In the left sidebar, navigate to **Build** &rarr; **Authentication**.
   * Click **Get Started** &rarr; select **Email/Password** and toggle it **Enabled**.
3. **Enable Cloud Firestore**:
   * Navigate to **Build** &rarr; **Firestore Database**.
   * Click **Create database** &rarr; choose your region and start in **Test mode** (or configure security rules).
4. **Register Web App**:
   * In Project Settings &rarr; **General** &rarr; **Your apps** &rarr; click the **Web** (`</>`) icon.
   * Copy the `firebaseConfig` keys (`apiKey`, `appId`, `projectId`, `messagingSenderId`).
5. **Paste into `lib/firebase_options.dart`**:
   * Open `lib/firebase_options.dart` and replace the placeholder values in `web` and `android` with your keys.

---

### Method 2: Android App Integration
1. In Firebase Console, click **Add app** &rarr; select **Android**.
2. Enter the package name: `com.padcare.padcare`
3. Download the generated `google-services.json` file.
4. Move `google-services.json` into:
   ```
   android/app/google-services.json
   ```
   *(The Gradle build script is already set up to detect and apply Google Services automatically when this file is present).*

---

### Architecture Overview

* **`lib/firebase_options.dart`**: Holds your Firebase API keys and options per platform.
* **`lib/services/firebase_service.dart`**:
  * `FirebaseService.initialize()`: Safely boots Firebase and detects offline vs online status.
  * `AuthService`: Real email/password sign-in and account creation (`FirebaseAuth`).
  * `FirestoreService`: Real-time cloud synchronization for requests (`/requests`) and school stock levels (`/schools`).
