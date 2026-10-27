# PadCare

**Care within reach.**

PadCare is a Flutter app concept for helping girls and women find menstrual-product support from schools, clinics, NGOs, community centres, and other local providers.

The current repository contains a working **local preview/prototype** with parent/guardian and school-staff flows, sample collection points, local request storage, and school inventory/request screens. It is not yet a live service directory: sample provider information and stock must not be treated as confirmed real-world availability.

## Product goals

- Help people discover nearby sanitary-pad collection points.
- Clearly distinguish verified providers from unverified listings.
- Show stock only when a provider has recently confirmed availability.
- Let providers maintain collection instructions, opening hours, and inventory.
- Offer age-appropriate menstrual-health education.
- Provide an optional **Donate to PadCare Project** flow for supporting app development. This is separate from donating sanitary products.
- Minimise sensitive personal data and keep help-seeking discreet.

## Design direction

Use a calm, accessible turquoise-and-mint visual system inspired by the PadCare reference:

- Turquoise: `#35B9B4`
- Deep teal: `#116B78`
- Mint: `#A5EAC5`
- Pale mint: `#E4F8F2`
- White surfaces with dark navy/charcoal text
- Rounded cards, subtle borders, clear availability states, and restrained transitions

Core experience: gradient splash screen; white home dashboard with the “Pads are within reach” hero; category chips; nearby provider cards; a mint developer-donation banner; map/list discovery; provider details; education; and profile navigation.

## Current implementation status

| Area | Current status |
| --- | --- |
| Flutter app and PadCare branding | Present |
| Parent/guardian and school-staff preview flows | Present |
| Local request and stock persistence | Present; signed-in request and staff inventory sync are implemented, pending Firebase configuration |
| Provider discovery UI and sample collection points | Present; data is illustrative |
| GPS distance and Google Maps directions | Implemented for verified provider records; requires device/platform testing |
| Firebase email/password and role-aware routing | Implemented; requires Firebase configuration and testing |
| Verified provider stream and freshness-aware stock status | Implemented; requires verified Firestore records |
| Menstrual-health education section | Interactive guides present; qualified local review still needed |
| Developer donation screen and payment-provider integration | Donation messaging present; payment gateway not connected |

See the [implementation roadmap](docs/IMPLEMENTATION_ROADMAP.md) and [Firebase setup guide](docs/SETUP_FIREBASE.md) for next steps, configuration, and security safeguards.

## Run locally

1. Install the Flutter SDK compatible with the SDK constraint in `pubspec.yaml`.
2. Clone this repository and enter its directory.
3. Run `flutter pub get`.
4. Run `flutter run` on an available emulator or connected device.

Before shipping, run:

```bash
flutter analyze
flutter test
flutter build apk
```

The Firebase adapter, email/password screens, Firestore request/inventory sync, and verified-provider stream are implemented. This repository does not include your Firebase project configuration or provider records, so online mode remains unavailable until you configure your own project and deploy the rules. Follow the [Firebase setup guide](docs/SETUP_FIREBASE.md).

## Privacy and safety principles

- Never invent provider locations, distances, verification status, or stock availability.
- Label demo/sample content clearly.
- Do not ask for a girl's name, age, or class unless a justified, reviewed requirement exists.
- Never expose provider contact information without permission.
- Do not claim a donation succeeded until the payment provider confirms it.
- Keep developer contributions separate from sanitary-product donations.
