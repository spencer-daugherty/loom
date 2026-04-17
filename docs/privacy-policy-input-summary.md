# Privacy Policy Input Summary

Date reviewed: 2026-04-12
Project reviewed: Loom iOS app

## Product Summary
- Loom is a personal planning, fulfillment, goal, reflection, and AI-assisted productivity app.
- The app stores user-created content across purpose, passions, fulfillment areas, goals, little wins, reflections, plans, capture inbox items, chat threads, and onboarding diagnostic/personalization flows.
- The app offers optional premium access through StoreKit 2 products:
  - `loom.lifetime` non-consumable
  - `loom.annual.locked` auto-renewable subscription
  - `loom.monthly` auto-renewable subscription

## Third-Party Services and Apple Frameworks in Use
- Firebase Auth
- Firebase Analytics
- Firebase Crashlytics
- Firebase Firestore
- Google Sign-In
- StoreKit 2
- CloudKit through SwiftData model storage
- Apple Intelligence when available on supported devices
- HealthKit
- Apple Health read authorization
- UserNotifications
- Camera and Photos frameworks

## Account and Identity Data
- Sign in with Apple is supported.
- Google sign-in is supported.
- Firebase Authentication is used for account identity.
- The app stores, when available:
  - auth provider
  - Firebase user ID
  - Apple user ID
  - Google user ID
  - account email
  - account display name
- Session and onboarding flags are stored in `UserDefaults`.

## Core User Content Stored by the App
- Free-form purpose and vision text
- Passions and emotional tags
- Fulfillment categories, missions, identities, roles, focus items, resources, scores, and archives
- Goals / outcomes, measures, entries, progress data, links, and archives
- Little Wins, completions, schedules, integration settings, and related history
- Plans, action blocks, steps, leverage selections, sensitivity-place links, notes, attachments, and archives
- Capture inbox items, recurring capture rules, recurring dispatches, and quick-complete items
- Vacation mode settings and vacation archives
- Recently deleted item records
- LoomAI chat threads and chat messages
- Diagnostic snapshots, diagnostic insights, purpose profile snapshots, and personalization history
- App feedback submissions from the account page

## Local Storage and On-Device Persistence
- Main app content is stored with SwiftData.
- The app attempts to use CloudKit-backed SwiftData storage when available, with local fallback if CloudKit is unavailable.
- Some personalization state is also cached in JSON files under Application Support.
- Additional lightweight settings and state are stored in `UserDefaults`.
- Camera snapshots can be saved to the user’s Photos library only when the user explicitly chooses Save.

## Sync and Remote Storage
- SwiftData content may sync through Apple CloudKit when the user has iCloud-backed sync available.
- Personalization snapshots may sync to Firebase Firestore for authenticated Firebase users.
  - Firestore path used in code:
    - `users/{uid}/personalization/current`
    - `users/{uid}/personalization/history/snapshots`
- App feedback is written to Firestore collection:
  - `app_feedback`
- Feedback payload currently includes:
  - rating
  - optional details text
  - submitted timestamp
  - app version / build
  - platform
  - source
  - user key
  - Firebase UID if available
  - email if available
  - name if available
  - auth provider if available

## Analytics and Diagnostics
- Firebase Analytics events are logged when analytics collection is enabled.
- Analytics code comments explicitly say payloads should avoid PII and free-text content.
- Firebase Crashlytics is enabled in non-debug builds and disabled in debug builds.
- App debug activity logging also exists in local runtime logs.

## AI Features and Data Flow
- Loom includes AI-assisted onboarding, chat, and suggestion-generation features.
- The app supports Apple Intelligence generation on supported devices.
- The app also includes a remote AI service path through:
  - `https://loom-ai-minimal.spence0927.workers.dev`
- The checked-in worker code (`loom/worker.js`) sends requests to OpenAI’s Responses API.
- The AI request payloads can include:
  - chat messages
  - personalization and onboarding summaries
  - fulfillment, goal, and capture context
  - action-block and current-reality context
  - client metadata such as app version, locale, timezone, request IDs, request hashes, and remaining daily response counts
- Current runtime behavior indicates Apple Intelligence requests can still fall back to the remote worker on certain failures.
- Privacy policy should clearly disclose:
  - what user text may be sent off device
  - that Apple Intelligence may be used on device when available
  - that remote AI processing may involve Loom’s worker and OpenAI

## Personalization and Inference
- The app computes onboarding personality/profile matching deterministically on device.
- The app stores diagnostic answers and personalization snapshots over time.
- The app derives inferred traits, a personality profile, and related insights from onboarding responses.
- LoomAI features also use user context to generate personalized suggestions, plans, and rewrites.
- Privacy policy should disclose that the app creates inferred personalization and profile data from user responses and in-app behavior/context.

## Health and Wellness Data
- If the user opts in, Loom requests HealthKit read access for supported metrics including:
  - steps
  - workout minutes
  - sleep data
- Health usage appears to be optional and permission-based.
- Privacy policy should clearly state Health integration is optional and user-controlled.

## Camera, Photos, Notifications, and Imported Media
- Loom requests camera permission for the Little Wins share camera.
- Loom requests add-only Photos permission to save generated share images.
- The app also supports user-selected photo imports in some planning/action flows through PhotosPicker.
- Loom requests notification permission for reminders and local notifications.

## Purchases and Entitlements
- StoreKit 2 is used for product loading, purchasing, entitlement checks, and restore purchases.
- The app determines premium access using `Transaction.currentEntitlements`.
- Restore purchases uses `AppStore.sync()`.
- The app stores the current subscription plan name locally for UI display.
- Purchase records themselves are handled by Apple, not a custom Loom billing backend.

## Data That Appears To Be Transmitted Off Device
- Firebase Authentication data needed for sign-in
- Firebase Analytics event telemetry
- Firebase Crashlytics crash diagnostics in non-debug builds
- Firestore personalization snapshots for authenticated users
- Firestore app feedback submissions
- Google Sign-In authentication flows
- AI requests sent to Loom’s worker and then OpenAI when the worker path is used
- CloudKit sync data for SwiftData-backed app content when enabled

## Sensitive / High-Risk Areas The Policy Should Explicitly Cover
- Free-form personal text entered into goals, purpose, reflections, relationship notes, and LoomAI chat
- Health data access
- AI processing and vendor chain
- Cloud sync and Firebase sync
- Account identity data
- User-generated photos or saved camera outputs

## Edge Cases and Open Questions For The Final Policy Writer
- Confirm whether all SwiftData model types are intended to sync through CloudKit in production, or whether some sensitive models should remain local-only.
- Confirm the final production hosting/domain for the Privacy Policy URL that will be used in App Store Connect.
- Confirm whether the remote AI worker always uses OpenAI in production, and whether any additional vendors, retention controls, or logging layers exist outside this repo.
- Confirm the intended retention/deletion policy for:
  - Firestore personalization history
  - Firestore app feedback
  - Firebase Analytics data
  - Crashlytics data
  - AI worker logs and upstream model-provider logs
- Confirm whether imported user photos are ever uploaded anywhere, or remain device-local only.
- Confirm whether notification content can include sensitive personal text.
- Confirm whether account deletion or data deletion requests will be handled only in-app or also through an external support/contact flow.
- Confirm whether any support email, legal entity name, or mailing address should appear in the final policy.

## App Review / Metadata Follow-Up
- A final hosted Privacy Policy URL still needs to be supplied in App Store Connect.
- If desired, the app can also read a hosted privacy-policy URL from an Info.plist `PrivacyPolicyURL` value for the in-app link destination.
- License Agreement can rely on Apple’s Standard EULA.
