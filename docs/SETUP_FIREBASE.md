# Configure Firebase for PadCare

The repository now contains a Firebase adapter and Firestore rules, but it does **not** contain your Firebase project credentials. Online features stay disabled until you configure your own project. Do not commit service-account keys or private credentials.

## 1. Create and configure the Firebase project

1. Create a project in the Firebase Console.
2. In **Authentication → Sign-in method**, enable **Email/Password**.
3. Create a **Cloud Firestore** database.
4. Register the Android app with application ID `com.padcare.padcare` and place the downloaded `google-services.json` at `android/app/google-services.json`.
5. Register the iOS app using the bundle identifier from Xcode and add `GoogleService-Info.plist` to the iOS Runner target.
6. Run `flutter pub get`, then launch the app on the configured platform. Without platform config, PadCare stays in local-preview mode.

Web builds need Firebase web options. Run FlutterFire CLI configuration for your project and initialise Firebase with the generated `DefaultFirebaseOptions.currentPlatform` in `lib/services/padcare_backend.dart` before enabling web.

## 2. Deploy the Firestore rules

Install and sign in to the Firebase CLI, select your own project, then deploy the checked-in rules:

```bash
npm install -g firebase-tools
firebase login
firebase use --add
firebase deploy --only firestore:rules
```

Review the rules against your real data model before production. Do not replace them with open rules such as `allow read, write: if true`.

## 3. Create verified provider listings

Provider records are stored in `facilities/{facilityId}`. Add records through a trusted administrator workflow or Firebase Console. Suggested fields:

| Field | Type | Notes |
| --- | --- | --- |
| `name` | string | Public provider name |
| `category` | string | `Schools`, `Clinics`, `NGOs`, or `Community` |
| `area` | string | Town, neighbourhood, or community |
| `address` | string | Public directions/address approved by provider |
| `latitude`, `longitude` | number | Real coordinates, not guessed coordinates |
| `hours` | string | Provider-confirmed hours |
| `instructions` | string | Approved collection instructions |
| `supplies` | string | What the provider says it distributes |
| `isVerified` | boolean | Set to true only after verification |
| `stockAvailable` | boolean | Provider-confirmed current availability |
| `stockUpdatedAt` | timestamp | Update whenever availability is confirmed |

PadCare displays stock as available only when `stockAvailable` is true and `stockUpdatedAt` is within the previous 24 hours. Otherwise availability is unknown. The current client supports external Google Maps directions; the stylised in-app map remains a preview rather than a live map tile view.

## 4. Provision school staff securely

Do not let users grant themselves school-staff access. Create the Firebase Authentication user through an approved process, then provision `users/{uid}` through an administrator-controlled workflow with fields such as:

```json
{
  "uid": "AUTH_USER_UID",
  "role": "schoolStaff",
  "facilityId": "st-marys-secondary",
  "facilityName": "St. Mary's Secondary"
}
```

The `facilityId` must match the provider document ID and the slug used by the request service. Parent self-registration can create only `role: parent` profiles. Staff must be tested with the exact facility assignment before using the inventory and request-review tools.

## 5. What is and is not connected

- **Firebase email/password:** implemented, awaiting project configuration.
- **Pickup requests:** saved locally first; sync to Firestore for signed-in users.
- **Staff request review and inventory:** remote writes are attempted for provisioned school-staff profiles; local preview remains available if sync fails.
- **Verified provider directory:** streams verified Firestore facility documents.
- **Nearby distance:** asks for location only after the user taps “Find Pads Near Me”; area browsing remains available if permission is declined.
- **Directions:** opens Google Maps using the provider's real coordinates or address.
- **Donations:** no payment gateway is connected. The current screen must not be treated as a completed payment flow.

## 6. Before launch

- Test Firestore rules in the Firebase Emulator Suite.
- Verify every provider and re-check stock-update timestamps.
- Add a trusted provider onboarding/verification workflow.
- Add transactional inventory reservations to prevent simultaneous requests overselling stock.
- Configure account recovery and email verification.
- Run `flutter analyze`, `flutter test`, and Android/iOS release builds.
- Have a qualified local health professional review educational content.
