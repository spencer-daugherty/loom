# Loom App Store Connect Audit

Date reviewed: 2026-04-18  
Project reviewed: Loom iOS app and Share into Loom extension  
App version / build: 0.1 (8)  
Main bundle ID: `srd.loom`  
Extension bundle ID: `srd.loom.ShareIntoLoomExtension`

## Executive Status

This audit reflects the current working tree after the App Privacy, link preview, review-note, and release-hardening changes.

Current submission posture:

- Hosted Privacy Policy URL: `https://spencer-daugherty.github.io/loom/`
- Hosted User Privacy Choices URL: `https://spencer-daugherty.github.io/loom/support.html#privacy-choices`
- Hosted Support URL: `https://spencer-daugherty.github.io/loom/support.html`
- Standard license agreement: Apple's Standard EULA
- Tracking: `No`
- Release builds: no release-visible developer toggles, no release raw-data inspector access, no release in-memory debug log retention, and no release persistence of rich AI debug payloads

Evidence boundary:

- Included: the shipping `loom` app target, the `Share into Loom` extension, public policy/support docs, and App Review materials
- Excluded: tests, `*.tmp` files, deleted admin/demo scripts, and other non-shipping repo artifacts
- Shipping-boundary enforcement for the `loom` target now explicitly excludes `loom/tests` and current `*.tmp` artifacts through project membership exceptions in `Loom Life Manager.xcodeproj/project.pbxproj`

## Final App Privacy Answers

Apply these exact changes to the current App Store Connect submission:

### Remove from `Data Linked to You`

1. `Health`
2. `Fitness`
3. `Performance Data`

### Keep in `Data Linked to You`

1. `Other User Content`
   - Uses: `App Functionality`, `Product Personalization`
2. `Name`
   - Uses: `App Functionality`
3. `Email Address`
   - Uses: `App Functionality`
4. `User ID`
   - Uses: `App Functionality`
5. `Device ID`
   - Uses: `Analytics`
6. `Purchase History`
   - Uses: `Analytics`
7. `Product Interaction`
   - Uses: `Analytics`
8. `Crash Data`
   - Uses: `App Functionality`, `Analytics`
9. `Other Diagnostic Data`
   - Uses: `App Functionality`, `Analytics`

### Notes behind those answers

- `Health` and `Fitness` are used on device through Apple HealthKit, but the current code does not transmit that data to Loom-managed servers.
- `Performance Data` is not supported by the current shipping dependency/config surface. Firebase Crashlytics is present; Firebase Performance Monitoring is not.
- `Name`, `Email Address`, and `User ID` are supported by sign-in/account management and feedback submission behavior.
- `Other User Content` is supported by Firestore personalization sync and app feedback content.
- `Device ID`, `Purchase History`, and `Product Interaction` are retained as the conservative-accurate analytics posture for the current submission.
- `Crash Data` and `Other Diagnostic Data` remain disclosed because Crashlytics is enabled in production builds and Firebase analytics/diagnostic behavior remains assumed to match code and official guidance.

## Privacy Policy / Support Alignment

Public docs now need to stay aligned to this exact story:

- HealthKit and Reminders remain on device and in Apple frameworks unless the user separately shares that data elsewhere.
- Loom does not upload attachments, imported files, or preview cache entries to Loom-managed servers as part of the core feature flow.
- Link previews use Apple system preview services plus local caching.
- Eligible production installs may send analytics and diagnostic data to Firebase.
- Eligible production installs may record purchase and subscription interaction analytics events.
- Privacy/deletion/help actions are available at `https://spencer-daugherty.github.io/loom/support.html#privacy-choices`.

Public source-of-truth docs:

- `docs/index.html`
- `docs/support.html`

## Link Preview Resolution

Link preview handling is now expected to be treated as resolved if the shipping code matches this checklist:

- Preview metadata is fetched through Apple `LinkPresentation`.
- The main-app preview cache stores hashed keys only, not raw URL strings, in durable local storage.
- Legacy raw-key preview cache storage is cleared.
- Preview images remain cached locally only.
- The share extension does not add any Loom/Firebase upload path for shared links or preview metadata.
- No analytics or debug logging should record raw shared URLs as part of the preview flow.

Evidence files:

- `loom/AttachmentPreviewComponents.swift`
- `ShareIntoLoomExtension/ShareViewController.swift`

## App Review Notes

### Attachment requirements

`docs/app-review-attachment.rtf` should remain synchronized with the shipping review flow:

- Reviewer uses `Continue with more options`
- Reviewer uses `Email sign in`
- Reviewer enters the credentials from App Review Information
- Reviewer sees a brief seeded-workspace splash
- Reviewer lands in the seeded demo workspace
- Optional permissions are not required for initial review
- Delete Account remains available
- Subscription management remains Apple-native
- Share extension remains reviewable from the iOS Share Sheet

### Paste-ready submission notes

Use this text in App Store Connect `Notes for Review`:

```text
Loom supports one disclosed App Review demo account. Please use the credentials entered in App Review Information.

Review steps:
1. Open the app.
2. Tap "Continue with more options."
3. Tap "Email sign in."
4. Enter the review credentials from App Review Information.

Expected behavior:
- The review account signs in through the standard email/password flow.
- After sign-in, Loom may briefly show the standard splash while a locally seeded isolated demo workspace finishes preparing.
- The `demo@loomlife.us` review account opens with stable seeded data and bypasses first-run setup so the full app can be reviewed immediately.
- No hidden review toggles, remote demo provisioning, backend demo-plan overrides, or release-visible developer tools are included in the shipping build.
- Optional permissions such as Health, Reminders, Camera, Photos, and Notifications are not required for initial review.
- Delete Account is available in Account.
- Subscription management uses Apple’s native subscription management flow.
- The Share into Loom extension can be tested separately from the iOS Share Sheet with shared text, links, images, videos, or files.

Privacy / technical notes:
- Link preview cards use Apple system preview services and local caching only.
- The shipping build does not expose internal debug or developer-only controls.
```

## Release-Build Compliance Checklist

These checks should remain true for the App Store build:

1. `LoomDeveloperBuild` gates all internal toggles and internal-only UI.
2. Release builds do not retain the in-memory `AppDebugActivityLog`.
3. Release AI chat persistence does not retain rich internal debug payloads; only release-safe provider/source metadata may remain.
4. Release builds do not expose `Manage Raw Data` as a usable internal data-inspector surface.
5. Demo account support remains limited to the disclosed seeded review path.
6. No retired task-sync, remote review-mode, or demo-plan metadata is reintroduced into the app bundle.
7. The Xcode synchronized `loom` root group keeps `loom/tests` and `*.tmp` artifacts out of the shipping app target.

## Manual App Store Connect Checklist

1. Apply the App Privacy edits above exactly.
2. Set `User Privacy Choices URL` to `https://spencer-daugherty.github.io/loom/support.html#privacy-choices`.
3. Verify `Privacy Policy URL` remains `https://spencer-daugherty.github.io/loom/`.
4. Paste the final review notes into App Review `Notes for Review`.
5. Enter the live demo credentials only in App Review Information.
6. Reconfirm monetization metadata still matches the in-app paywall exactly.
7. Submit only after the hosted policy/support pages are published with the latest text.

## Residual Risk

Repo-controlled blocking issues are treated as resolved once the code and docs above ship together.

Remaining non-repo risk is limited to:

- Apple’s discretionary review judgment
- manual mistakes when copying the final App Privacy answers or review notes into App Store Connect
