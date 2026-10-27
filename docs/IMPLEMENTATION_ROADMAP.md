# PadCare implementation roadmap

This roadmap adapts the supplied Muse AI master prompt to the current Flutter repository. Preserve working local-preview flows while moving toward a real, testable product in small increments.

## Phase 1 — Align the existing prototype

- Adopt the turquoise/mint palette and shared design tokens consistently.
- Build the splash and home dashboard around “Pads are within reach”.
- Keep category chips, provider cards, and map/list navigation visually consistent.
- Add a clearly labelled developer-support banner and a separate donation screen.
- Remove hard-coded personal identity from the default landing experience.
- Ensure every sample provider and stock figure is labelled as demonstration data; do not show sample data as genuinely verified or currently in stock.

## Phase 2 — Discovery and provider details

- Implemented: search and category filtering for provider listings, including live verified records when Firebase is configured.
- Implemented: provider detail cards with address/directions, hours, collection instructions, and freshness-aware availability fields.
- Stream verified provider records from Firestore and open real provider directions in Google Maps.
- Compute distance from the user's location only after they tap the nearby-search action and grant permission.
- Request location permission contextually; keep manual area/town search available when permission is denied.
- Implemented: open Google Maps directions using a live provider's coordinates or address.
- Display “Availability unknown” for missing or stale stock data.

## Phase 3 — Secure backend and provider management

- Select Firebase or Supabase and document the choice.
- Implement Firebase email/password sign-in, parent account creation, sign-out, and role-aware routing. Password reset remains a follow-up.
- Implemented: Firestore provider stream, request sync, and authorised staff inventory/request access. Trusted administrator provisioning of providers/staff and transactional stock reservations remain outstanding. Provider documents currently need to be provisioned through a trusted admin process.
- Enforce authorization on the backend, not only in UI logic.
- Add a review workflow for provider verification; account creation alone must never grant a verified badge.
- Use atomic inventory/request updates to avoid double reservations and overselling.

## Phase 4 — Education and donations

- Implemented: interactive menstrual-health learning guides. Have qualified local health professionals review the content before public launch.
- Add a distinct “Donate to PadCare Project” page explaining that contributions support app development.
- Keep developer donations separate from donations of pads or other supplies.
- Integrate a supported payment provider only after merchant setup and credentials are available. The current app deliberately does not take payments.
- Never store raw payment-card details or display success before provider confirmation.

## Phase 5 — Quality gates

- Add tests for search/filtering, request lifecycle, inventory reservations, stale stock, and role permissions.
- Run `flutter analyze`, `flutter test`, and platform builds in CI.
- Check loading, empty, offline, permission-denied, payment-cancelled, and error states.
- Verify accessibility: contrast, scalable text, semantics, and comfortable touch targets.
- Document all required secrets and platform configuration; never commit credentials.

## Honest delivery rule

A screen that looks complete is not necessarily connected. Report each capability as one of: implemented and tested, implemented but unverified, demo-only, or awaiting configuration. Never imply that live providers, real stock, authentication, maps, or payments are operational until they have been tested end-to-end.


## Recent implementation update

- The profile now distinguishes online accounts from local preview mode and labels the staff interface as a demo unless the user has an authorised school-staff account.
- Added a widget test for the profile's preview and staff-access messaging.
