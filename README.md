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
| Local request and stock persistence | Present in the prototype |
| Provider discovery UI and sample collection points | Present; data is illustrative |
| Real map, GPS-based distance, and external directions | Requires implementation/verification |
| Live authentication and role-based backend security | Not established |
| Live provider verification and current stock feeds | Not established |
| Menstrual-health education section | Requires implementation/verification |
| Developer donations and payment-provider integration | Requires implementation/verification |

See [the implementation roadmap](docs/IMPLEMENTATION_ROADMAP.md) for the next steps and safeguards.

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

Firebase packages are declared, but package presence alone does not mean Firebase is configured or that the current preview sends data to a backend. Configure platform Firebase files and secure backend rules before enabling live accounts or provider data.

## Privacy and safety principles

- Never invent provider locations, distances, verification status, or stock availability.
- Label demo/sample content clearly.
- Do not ask for a girl's name, age, or class unless a justified, reviewed requirement exists.
- Never expose provider contact information without permission.
- Do not claim a donation succeeded until the payment provider confirms it.
- Keep developer contributions separate from sanitary-product donations.
