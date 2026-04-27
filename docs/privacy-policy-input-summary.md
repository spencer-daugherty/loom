# Privacy Policy Input Summary

Date reviewed: 2026-04-18  
Project reviewed: Loom iOS app

## Product Summary
- Loom is a personal planning, fulfillment, goal, reflection, and AI-assisted productivity app.
- The app stores user-created content across purpose, passions, fulfillment areas, goals, little wins, reflections, plans, capture inbox items, chat threads, and onboarding diagnostic/personalization flows.
- The app offers optional premium access through StoreKit 2 products:
  - `lifetime` non-consumable
  - `annual` auto-renewable subscription
  - `monthly` auto-renewable subscription

## Third-Party Services and Apple Frameworks in Use
- Firebase Auth
- Firebase Analytics
- Firebase Crashlytics
- Firebase Firestore
- Google Sign-In
- StoreKit 2
- Apple Intelligence on supported devices
- local compatibility logic on unsupported devices
- HealthKit
- EventKit / Reminders
- UserNotifications
- Camera and Photos frameworks

## Account and Identity Data
- Sign in with Apple is supported.
- Google Sign-In is supported.
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
- The main SwiftData database is stored locally on device.
- Some personalization state is also cached in JSON files under Application Support.
- Additional lightweight settings and state are stored in `UserDefaults`.
- Camera snapshots can be saved to the user’s Photos library only when the user explicitly chooses Save.
- Shared content from the Share into Loom extension is written into the app-group container before the main app ingests it.

## Sync and Remote Storage
- Personalization snapshots may sync to Firebase Firestore for authenticated Firebase users.
  - Firestore paths used in code:
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
- Firebase Analytics is limited to production-only funnel, retention, setup, paywall, and purchase telemetry:
  - onboarding started / completed / abandoned
  - signup started / completed / abandoned
  - diagnostic started / completed / abandoned
  - quick tour started / step viewed / completed
  - post-paywall setup started / step viewed / step completed / exited / completed
  - paywall viewed / abandoned / pricing option selected
  - purchase started / completed / failed and restore started / completed
  - first activation, core opened, daily active, retention day 1, retention day 3, retention day 7
- StoreKit purchase revenue may be reported to Firebase Analytics through Firebase's StoreKit transaction integration when analytics collection is enabled in eligible production installs.
- Analytics events must not include user-authored Purpose, Fulfillment, Goal, diagnostic, LoomAI chat, reminder, feedback, or free-text planning content.
- Firebase Analytics collection is disabled in debug builds, previews, debugger-attached sessions, review/demo workspace sessions, and TestFlight or sandbox-receipt installs.
- Firebase Crashlytics is enabled in non-debug builds and disabled in debug builds.
- App debug activity logging may exist locally, but the production privacy story should focus on Firebase Analytics and Crashlytics.
- Final App Store Connect posture should keep `Crash Data` and `Other Diagnostic Data`, keep conservative analytics disclosures such as `Device ID`, `Purchase History`, and `Product Interaction`, and remove `Performance Data`.

## AI Features and Data Flow
- Loom includes AI-assisted onboarding, chat, and suggestion-generation features.
- The app supports Apple Intelligence generation on supported devices.
- On devices without Apple Intelligence, the app uses local compatibility logic and local suggestion tables on device.
- The privacy policy should state:
  - Apple Intelligence may be used on device when available
  - unsupported devices use local on-device compatibility logic
  - AI features use user-provided text plus related planning and personalization context needed to answer the request

## Personalization and Inference
- The app computes onboarding personality/profile matching deterministically on device.
- The app stores diagnostic answers and personalization snapshots over time.
- The app derives inferred traits, a personality profile, and related insights from onboarding responses.
- LoomAI features use user context to generate personalized suggestions, plans, and rewrites.

## Health, Reminders, Camera, Photos, and Notifications
- HealthKit access is optional and read-only for supported metrics such as steps, workout minutes, and sleep.
- The app supports Apple Reminders sync for user-authorized reminder data.
- The app requests camera permission for the Little Wins share camera.
- The app requests add-only Photos permission to save generated share images.
- The app supports user-selected photo imports in planning/action flows through PhotosPicker.
- The app requests notification permission for reminders and local notifications.
- HealthKit and Reminders data remain on device and in Apple frameworks unless the user separately shares that data elsewhere.
- Final App Store Connect posture should remove `Health` and `Fitness` from `Data Linked to You` because the current shipping code does not transmit that data to Loom-managed servers.

## Purchases and Entitlements
- StoreKit 2 is used for product loading, purchasing, entitlement checks, and restore purchases.
- Premium access is determined using `Transaction.currentEntitlements`.
- Restore purchases uses `AppStore.sync()`.
- The app stores the current subscription plan name locally for UI display.
- Purchase records themselves are handled by Apple, not a custom Loom billing backend.

## Data That Appears To Be Transmitted Off Device
- Firebase Authentication data needed for sign-in
- Firebase Analytics funnel and retention telemetry when collection is enabled
- Firebase Crashlytics crash diagnostics in non-debug builds
- Firestore personalization snapshots for authenticated users
- Firestore app feedback submissions
- Google Sign-In authentication flows

## Sensitive Areas The Final Policy Must Cover
- Free-form personal text entered into goals, purpose, reflections, relationship notes, and LoomAI chat
- Health data access
- AI processing and on-device personalization
- Firebase sync
- Account identity data
- User-generated photos or saved camera outputs
- Feedback text and support/contact submissions

## App Review / Metadata Follow-Up
- The Privacy Policy URL in App Store Connect should point to `https://spencer-daugherty.github.io/loom/`.
- The Support URL in App Store Connect should point to `https://spencer-daugherty.github.io/loom/support.html`.
- The User Privacy Choices URL in App Store Connect should point to `https://spencer-daugherty.github.io/loom/support.html#privacy-choices`.
- App Store Connect privacy answers should be cross-checked against:
  - Firebase Authentication
  - Google Sign-In
  - Firebase Analytics
  - Firebase Crashlytics
  - Firestore personalization sync
  - Firestore app feedback submissions
- License Agreement can rely on Apple’s Standard EULA.
