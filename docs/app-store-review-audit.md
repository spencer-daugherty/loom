# Loom App Store Review Audit

Date reviewed: 2026-04-18  
Project reviewed: Loom iOS app

## Executive Verdict

Loom is submission-ready from the current repo-controlled review surface, assuming App Store Connect is updated to match the attached review notes and the final App Privacy answers in `docs/app-store-connect-audit.md`.

Intended App Review path:

- one disclosed demo account: `demo@loomlife.us`
- standard email/password sign-in through `Continue with more options` > `Email sign in`
- locally seeded isolated demo workspace with stable sample data
- no hidden review toggles, backend demo provisioning, or release-visible developer controls

## Review-Critical Checks

1. App Review notes must match `docs/app-review-attachment.rtf` exactly.
2. Live review credentials must appear only in App Review Information.
3. Optional permissions must remain skippable for the initial review path.
4. Apple Health must be visibly identified in the UI as an optional, read-only integration.
5. The first setup intro pages must remain scrollable with pinned bottom actions on review devices.
6. Delete Account must remain available in Account.
7. Subscription management must continue opening Apple’s native management flow.
8. The shipping build must not expose internal debug, raw-data, or developer-only controls.

## Resolved In This State

- The hosted privacy policy and support page use final public-facing language.
- The App Review attachment documents the exact demo-account path and optional-permission posture.
- The launch monetization posture remains one live lifetime purchase plus two disabled upcoming plans.
- Link preview handling is documented as Apple-system preview fetches plus local caching only.
- The release story remains Apple Intelligence on supported devices plus local fallback logic on unsupported devices.
- Release builds are expected to avoid retaining internal in-memory debug logs and rich AI debug persistence.
- The review build remains free of remote review-mode toggles and backend-driven demo-plan overrides.

## Permissions / Auth Status

- Sign in with Apple remains enabled.
- HealthKit remains read-only in practice.
- Camera / Photos usage strings are present.
- Reminders usage strings are present.
- Delete Account remains available with provider-aware reauthentication.

## Manual Submission Checklist

1. Paste the final reviewer notes from `docs/app-store-connect-audit.md` into App Store Connect.
2. Enter the current demo credentials only in App Review Information.
3. Verify App Privacy answers match `docs/app-store-connect-audit.md`.
4. Verify the Privacy Policy URL is `https://spencer-daugherty.github.io/loom/`.
5. Verify the User Privacy Choices URL is `https://spencer-daugherty.github.io/loom/support.html#privacy-choices`.
6. Verify the Support URL is `https://spencer-daugherty.github.io/loom/support.html`.
7. Verify subscription metadata in App Store Connect still matches the in-app paywall language.

## Docs Coverage Appendix

- `docs/app-store-review-audit.md`  
  Status: current App Review readiness summary.

- `docs/app-store-connect-audit.md`  
  Status: current App Privacy and submission metadata source of truth.

- `docs/index.html`  
  Status: current hosted privacy policy source.

- `docs/support.html`  
  Status: current hosted support and privacy-choices source.

- `docs/app-review-attachment.rtf`  
  Status: current App Review attachment for the preserved demo-login flow.
