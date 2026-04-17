# Loom App Store Review Audit

## 1. EXECUTIVE VERDICT

**Likely Reject**

The current repo looks like a pre-release build, not a clean submission build. There are shipping debug and developer surfaces, hardcoded review/demo account logic, stale alpha labeling, permission mismatches, and risky subscription copy that would invite scrutiny even before a reviewer gets into functionality. The most serious problems are not subtle: a temporary AI debug screen can be surfaced from persisted settings, a developer panel is reachable from production UI with a hardcoded PIN, Photos read permission appears missing for import flows, and review/demo credentials are embedded in the repo and supported by special-case onboarding logic. Privacy and entitlement declarations are also loose enough to create follow-up questions or a rejection if App Store Connect disclosures do not match precisely.

## 2. HIGH-RISK APPROVAL BLOCKERS

- **Issue:** Shipping AI debug screen and floating debug entry point are still wired into the main app. XXX-remove pages for production
  **Why Apple may care:** Reviewers reject builds that expose debug, diagnostics, or internal tooling in production. This also makes the app look unfinished and risky.
  **Evidence in repo:** [loomApp.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loomApp.swift:279) stores `enableLoomAIDebug` and `loom.showLoomAIDebugPage`; [loomApp.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loomApp.swift:294) routes directly to `TemporaryVisionAutoWriteDebugView`; [loomApp.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loomApp.swift:308) shows a floating `Debug` button; [TemporaryVisionAutoWriteDebugView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/TemporaryVisionAutoWriteDebugView.swift:8) explicitly says the file is temporary and should be deleted.
  **Recommended fix:** Remove the debug screen, its route, its `AppStorage` flags, and any production UI that can surface it. Do not rely on a hidden toggle.

- **Issue:** Developer panel is reachable in production based on account name plus a hardcoded PIN. XXX-remove pages for production
  **Why Apple may care:** Hidden admin controls, feature flags, paywall overrides, and raw data tools in a review build are classic rejection material. Hardcoded access logic also looks careless and unsafe.
  **Evidence in repo:** [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:902) shows a `Developer` button when the account name equals `Spencer`; [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:1003) unlocks with PIN `0927`; [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:1017) exposes reset-demo, raw-data, paywall, and feature-flag controls.
  **Recommended fix:** Remove the entire developer surface from submission builds. If internal tools are required, gate them behind compile-time debug-only flags and exclude them from release targets.

- **Issue:** Photos import appears to require read access, but the app only declares add-only Photos permission. 
  **Why Apple may care:** Missing or incorrect privacy purpose strings can cause runtime failure and direct rejection under privacy rules.
  **Evidence in repo:** [Info.plist](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Info.plist:40) contains `NSPhotoLibraryAddUsageDescription` but no `NSPhotoLibraryUsageDescription`; the app imports and previews user media in flows like [CaptureView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/CaptureView.swift:1273), [ActionView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/ActionView.swift:5753), and [PlanView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/PlanView.swift:9109). Saving camera output add-only is separately used in [LittleWinsShareCameraView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LittleWinsShareCameraView.swift:626).
  **Recommended fix:** Add the correct read permission string for any Photos import path, and make the wording specific to the actual user-facing feature.

- **Issue:** Review/demo accounts and credentials are not just provided for review; the app has product logic for them. OOO
  **Why Apple may care:** Apple accepts demo credentials when necessary, but special review-only behavior, seeded workspaces, and hardcoded passwords make the build look staged and non-production.
  **Evidence in repo:** [docs/app-review-attachment.rtf](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/docs/app-review-attachment.rtf:6) includes `demo@loomlife.us` and password `ForAllTime3`; [LoomDemoWorkspaceSeeder.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/App/LoomDemoWorkspaceSeeder.swift:14) defines special workspaces including `reviewDemo`, `reviewOnboardingDemo`, and `starter`; [AccountStepView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Onboarding/AccountStepView.swift:703) returns “This demo sign-in is not available right now”; [AccountStepView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Onboarding/AccountStepView.swift:753) branches on special workspace types.
  **Recommended fix:** Strip special review/demo logic from the shipping binary. If reviewer access is needed, use a normal production account with no review-only branching.

- **Issue:** The build presents itself as alpha software.
  **Why Apple may care:** Visible alpha/beta labeling signals an unfinished app and undermines the “complete, production-ready” standard.
  **Evidence in repo:** [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:860) shows `Version: 0.1.0-alpha.7`; [LoadingSplashView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoadingSplashView.swift:678) shows the same alpha label on the splash screen.
  **Recommended fix:** Remove pre-release labeling from the user-visible app before submission.

## 3. MEDIUM-RISK REVIEW CONCERNS

- **Issue:** HealthKit update permission is declared even though the code appears read-only.
  **Why Apple may care:** Overbroad health permissions trigger extra scrutiny. If the app requests write access it does not use, Apple may question necessity and privacy scope.
  **Evidence in repo:** Health strings are injected in the project with both share and update descriptions; code paths request read-only authorization with `toShare: nil` in [Models.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Models.swift:666) and [ObjectivesAddViewChart.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/ObjectivesAddViewChart.swift:189).
  **Recommended fix:** Remove Health update entitlement/usage text unless the app truly writes health data. Tighten purpose text to match actual read-only behavior.

- **Issue:** Screen Time integration uses `FamilyControls` APIs, but no family-controls entitlement is visible in the repo.
  **Why Apple may care:** Missing capability alignment can lead to broken review flows or rejection if a feature appears advertised but cannot function on the submitted binary.
  **Evidence in repo:** [FulfillmentView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/FulfillmentView.swift:5642) presents `FamilyActivityPicker`; [Models.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Models.swift:603) requests `AuthorizationCenter.shared.requestAuthorization`; [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:1) does not show a family-controls entitlement.
  **Recommended fix:** Verify the target has the required entitlement in the actual release configuration, or remove/hide the feature for submission.

- **Issue:** Push/background notification capability looks declared without a real push implementation.
  **Why Apple may care:** Unused or misleading capability claims increase review friction and can create privacy/disclosure mismatches.
  **Evidence in repo:** [Info.plist](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Info.plist:42) declares `remote-notification`; [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:5) uses `aps-environment` `development`; the app sets `UNUserNotificationCenter.current().delegate` in [loomApp.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loomApp.swift:250) but repo search did not find APNs registration or remote notification handlers.
  **Recommended fix:** Remove remote notification capability if the app only uses local notifications, or fully implement and verify push behavior in release config.

- **Issue:** Subscription copy contains time-limited and price-lock claims that can stale out or overstate the offer. OOO
  **Why Apple may care:** Reviewers scrutinize deceptive or confusing pricing language, especially around “lifetime,” free trials, and urgency-based claims.
  **Evidence in repo:** [SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift:54) uses `Founding Member (Lifetime)` and `Annual (Early Adopter)`; [SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift:139) says `price-lock for life`; [SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift:168) and [SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift:170) hardcode offer end dates.
  **Recommended fix:** Replace hardcoded urgency and “for life” marketing claims with language sourced from live StoreKit products or remove the claims entirely.

- **Issue:** The app syncs broad personal data through CloudKit without obvious in-app disclosure. OOO
  **Why Apple may care:** Silent iCloud sync of deeply personal content can create privacy-label and reviewer questions if not clearly disclosed.
  **Evidence in repo:** [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:17) enables iCloud/CloudKit; [loomApp.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loomApp.swift:284) uses `LoomModelContainerHost`; previous inspection confirmed the SwiftData model container is configured with `cloudKitDatabase: .automatic`, which likely sweeps in goals, reflections, insights, and chat history.
  **Recommended fix:** Make iCloud sync explicit in privacy/legal copy and confirm App Privacy labels reflect this storage/sync behavior.

- **Issue:** OAuth task-sync tokens are stored in `AppStorage`. OOO
  **Why Apple may care:** This is more of a security and trust problem than an App Review rule by itself, but it weakens the privacy posture if external account tokens are stored casually.
  **Evidence in repo:** [CaptureView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/CaptureView.swift:746) stores Google and Microsoft access/refresh tokens in `AppStorage`; mirrored access exists in [PlanView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/PlanView.swift:645).
  **Recommended fix:** Move third-party OAuth tokens to Keychain-backed storage and mention third-party account sync clearly in privacy disclosures.

## 4. LOW-RISK POLISH / TRUST ISSUES

- **Issue:** Diagnostic loading skeleton uses literal placeholder sentences.
  **Why Apple may care:** This is not a direct policy problem, but it looks sloppy and unfinished if a reviewer catches it.
  **Evidence in repo:** [DiagnosticInsightsView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/DiagnosticInsightsView.swift:696) shows `This placeholder line represents incoming LoomAI text.` and [DiagnosticInsightsView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/DiagnosticInsightsView.swift:701) shows `Second placeholder sentence while diagnostics load.`
  **Recommended fix:** Replace these with neutral skeleton-only placeholders or remove the literal filler text.

- **Issue:** Legal terminology is slightly careless.
  **Why Apple may care:** Mislabeling Apple’s Standard EULA as a custom “License Agreement” can confuse reviewers and users.
  **Evidence in repo:** [LegalLinksView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/LegalLinksView.swift:15) titles the terms sheet `License Agreement` even though [LegalLinksView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/LegalLinksView.swift:78) says Loom uses Apple’s Standard EULA.
  **Recommended fix:** Label it explicitly as Apple’s Standard EULA or Standard License Agreement.

- **Issue:** Review attachment directs the reviewer into a special “Other sign in” path. OOO
  **Why Apple may care:** It reinforces that the normal product is not what review is seeing.
  **Evidence in repo:** [docs/app-review-attachment.rtf](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/docs/app-review-attachment.rtf:10) tells reviewers to tap `Continue with more options` and `Other sign in`.
  **Recommended fix:** Minimize review-specific flow instructions and avoid special-case account routes in the shipping app.

## 5. PRIVACY / DATA DISCLOSURE AUDIT

- **What appears collected**
  - Account identifiers and auth-linked metadata through Firebase Auth, including email, display name, auth provider, and UID: [AccountStepView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Onboarding/AccountStepView.swift:480), [AppFeedbackService.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AppFeedbackService.swift:48).
  - In-app planning, reflections, goals, purpose/diagnostic data, chat history, and other personal productivity content stored in SwiftData and likely synced via CloudKit.
  - App feedback payloads with rating, details, app version/build, user key, Firebase UID, email, name, and auth provider: [AppFeedbackService.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AppFeedbackService.swift:66).
  - Analytics and crash/diagnostic data in release builds: [AnalyticsCollectionPolicy.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Analytics/AnalyticsCollectionPolicy.swift:7), [loomApp.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loomApp.swift:242).

- **What appears transmitted**
  - Firebase services for auth, analytics, crash reporting, and Firestore feedback.
  - Remote AI requests to Loom’s worker backend at `loom-ai-minimal.spence0927.workers.dev`: [LoomAIService.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoomAIService.swift:5).
  - The worker forwards prompts/context to OpenAI Responses API: [worker.js](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/worker.js:1).
  - Google Tasks and Microsoft To Do API traffic when sync is enabled: [CaptureView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/CaptureView.swift:6241), [CaptureView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/CaptureView.swift:6300).

- **What third parties appear involved**
  - Firebase Auth
  - Firebase Analytics
  - Firebase Crashlytics
  - Firebase Firestore
  - Google Sign-In
  - Google Tasks
  - Microsoft identity / Microsoft To Do
  - OpenAI via Loom’s remote worker
  - Apple CloudKit/iCloud

- **What the privacy policy must likely disclose**
  - Remote AI processing and the fact that user content may be sent to Loom’s backend worker and OpenAI.
  - Firebase analytics/crash reporting in production.
  - Firestore feedback submission with linked account fields.
  - CloudKit/iCloud syncing of user data.
  - External task-provider sync and token-based access.
  - Health, reminders, camera, and photos access scopes.

- **What App Privacy labels likely need to match**
  - Contact info if email/name are linked to feedback or account.
  - User content for plans, reflections, chat, and diagnostic/purpose content if transmitted or synced.
  - Identifiers and diagnostics for Firebase/Auth/Crashlytics.
  - Usage data/analytics for Firebase Analytics.
  - Potentially purchases/subscription data if linked to the user session.

- **Any mismatches or unknowns**
  - `docs/index.txt` already discloses remote AI and some Firebase flows, but `cannot verify from repo` whether App Store Connect privacy labels currently match.
  - `cannot verify from repo` whether production backend logs, retention, and deletion behavior match the policy.

## 6. ACCOUNT / AUTH / DELETION AUDIT

- **Whether account creation exists**
  - Yes. Email, Google, and Sign in with Apple are present through onboarding and Firebase Auth.

- **Whether Sign in with Apple implications exist**
  - Yes. Since Google sign-in exists for authentication, Sign in with Apple is appropriately present. The entitlement is declared in [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:7).

- **Whether in-app account deletion appears present or missing**
  - Present. The flow requires typing `DELETE`, plus reauthentication for email/Google/Apple as needed: [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:2276), [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:2460), [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:2551).

- **Any review risk here**
  - Medium risk: the local deletion flow looks real and materially better than many apps.
  - Medium risk: wording says account deletion removes personalization history and device data, but `cannot verify from repo` whether all remote data beyond Firebase Auth and local state is deleted. Firestore feedback retention is not obviously deleted by this flow.
  - Medium risk: special workspace handling for `reviewOnboardingDemo` is baked into deletion logic: [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:2482). That reinforces the problem that review/demo behavior is part of product logic.

## 7. SUBSCRIPTIONS / IAP AUDIT

- **Review of IAP/subscription/lifetime flows**
  - Product IDs are `loom.lifetime`, `loom.annual.locked`, and `loom.monthly`: [SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift:10).
  - `PurchaseManager` loads live products from StoreKit and tracks entitlements via `Transaction.currentEntitlements`: [PurchaseManager.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/PurchaseManager.swift:130), [PurchaseManager.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/PurchaseManager.swift:180).
  - The app supports lifetime alongside auto-renewables conceptually: [PurchaseManager.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/PurchaseManager.swift:124).

- **Restore behavior**
  - Restore exists and is accessible. Account settings call `purchaseManager.restorePurchases`: [AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift:2406).
  - This is a positive compliance point.

- **Billing language concerns**
  - Annual disclosure includes a 10-day free trial and standard auto-renew language, which is directionally correct.
  - The risky part is the marketing framing: `Founding Member`, `Early Adopter`, `price-lock for life`, and hardcoded end dates: [SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift:168), [SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift:170). This is only a real approval risk if the shipped copy drifts from the live StoreKit/App Store Connect configuration during submission or review.

- **Misleading pricing or offer language**
  - `loom.annual.locked` itself encodes special pricing in the product ID.
  - `originalPriceText` shows `$180` for annual: [SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift:109).
  - `Start in X days for price-lock for life` is only safe if that countdown and claim exactly match the live StoreKit offer and remain true while the build is in review.

- **Anything that could fail review or confuse reviewers**
  - Main risk is drift: App Store Connect products, screenshots, pricing metadata, review notes, and the in-app paywall copy must all match exactly.
  - `cannot verify from repo` whether all three products exist, are approved, and match these claims in App Store Connect.
  - Simplest safe path if the copy already matches StoreKit: treat this as a manual verification item, confirm the App Store Connect configuration immediately before submission, and note in App Review that the in-app language mirrors the live StoreKit offers.

## 8. PERMISSIONS / ENTITLEMENTS AUDIT

- **Camera**
  - Found: `NSCameraUsageDescription` in [Info.plist](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Info.plist:38).
  - Assessment: justified by in-app Little Wins camera capture.

- **Photos**
  - Found: `NSPhotoLibraryAddUsageDescription` only in [Info.plist](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Info.plist:40).
  - Assessment: incomplete for import/read flows. High risk.

- **Notifications**
  - Found: local notification request flow in [LoomNotifications.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoomNotifications.swift:125).
  - Assessment: local notifications appear justified. Remote push/background configuration appears overbroad and possibly dead.

- **Push / background remote notification**
  - Found: `remote-notification` background mode in [Info.plist](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Info.plist:42); `aps-environment` `development` in [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:5).
  - Assessment: unclear and likely dead in the submitted product.

- **Sign in with Apple**
  - Found: entitlement in [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:7).
  - Assessment: justified because third-party sign-in exists.

- **App Groups**
  - Found: app group entitlement in [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:11) and extension entitlement.
  - Assessment: justified by Share into Loom extension.

- **HealthKit**
  - Found: entitlement in [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:15); read-only requests in [Models.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Models.swift:676) and [ObjectivesAddViewChart.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/ObjectivesAddViewChart.swift:210).
  - Assessment: real feature, but permission scope appears broader than implementation.

- **iCloud / CloudKit**
  - Found: container and CloudKit services in [loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements:17).
  - Assessment: justified only if the app clearly discloses iCloud sync. Medium review risk otherwise.

- **Reminders**
  - Found: reminder access purpose strings are set in project build settings; real EventKit integration exists in Capture/Plan/Action/Reflect flows.
  - Assessment: justified.

- **FamilyControls / Screen Time**
  - Found: API usage but no visible entitlement in the checked entitlements files.
  - Assessment: unclear and likely risky until release capability alignment is verified.

## 9. AI / APPLE INTELLIGENCE / NETWORK AUDIT

- **What AI features exist**
  - LoomAI chat and prompt generation.
  - Diagnostic insights.
  - Purpose/vision/passions rewrite or autowrite flows.
  - Shared capture autowrite and related assistance.

- **What is on-device vs remote**
  - Apple Intelligence and local compatibility logic exist in the client for some flows: [LoomAIChatProvider.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoomAIChatProvider.swift:1), [AppleIntelligenceSupport.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AppleIntelligenceSupport.swift:1).
  - Remote AI definitely still exists through Loom’s worker service: [LoomAIService.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoomAIService.swift:5), [worker.js](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/worker.js:1).

- **What is disclosed vs not disclosed**
  - Repo docs already disclose remote AI and OpenAI involvement in `docs/index.txt`.
  - Medium risk remains if in-app wording or App Store metadata implies Apple Intelligence or on-device processing more broadly than is true.

- **Review risks or misleading claims**
  - High risk: the temporary debug screen exposes raw AI request/response tooling and endpoints in the shipped build.
  - Medium risk: AI branding in tips, marketing, or UI could overstate capabilities if reviewers test unsupported paths.
  - Medium risk: diagnostic insight generation operates on sensitive life, health, and planning context. The app should avoid implying authoritative or deterministic advice.
  - Medium risk: `cannot verify from repo` whether the app gives users enough runtime disclosure that some AI features are processed remotely.

## 10. MANUAL APP STORE CONNECT CHECKLIST

- Confirm App Privacy labels exactly match:
  - Firebase Auth data
  - Analytics
  - Crash diagnostics
  - Firestore feedback
  - CloudKit sync
  - Remote AI/OpenAI processing
  - Third-party task sync
- Confirm all live IAPs exist and match in-app product IDs:
  - `loom.lifetime`
  - `loom.annual.locked`
  - `loom.monthly`
- Confirm pricing, trial length, and any “original price” comparison shown in the app are legally supportable and match App Store Connect.
- Confirm release entitlements actually include or exclude FamilyControls as intended.
- Confirm the submission build removes all debug/developer/demo-only surfaces.
- Confirm screenshots, subtitles, promotional text, and descriptions do not overclaim Apple Intelligence, AI personalization, Health integration, or subscription benefits.
- Confirm the hosted privacy policy at `https://spencer-daugherty.github.io/loom/` is live, accurate, and stable.
- Confirm account deletion removes all required remote user data or that the policy accurately explains any retained records.
- Confirm production APNs config is either complete and used or removed entirely from the submission build.

## 11. PRIORITIZED FIX PLAN

- **Must fix before submission**
  - Remove `TemporaryVisionAutoWriteDebugView` and all release wiring to it.
  - Remove the production developer panel, hardcoded PIN, and release-accessible feature flags.
  - Remove review/demo-only auth and workspace behavior from the shipping binary.
  - Fix Photos permission coverage for import/read flows.
  - Remove alpha labeling from all user-visible surfaces.
  - Clean up or remove deceptive/stale subscription marketing claims and dates.

- **Should fix before submission**
  - Tighten HealthKit permissions to read-only if that is the actual behavior.
  - Resolve Screen Time entitlement mismatch or hide the feature.
  - Remove dead remote-notification capability if the app only uses local notifications.
  - Move third-party OAuth tokens out of `AppStorage`.
  - Replace literal placeholder strings in diagnostic loading UI.
  - Make iCloud sync and remote AI processing clearer in privacy-facing copy if currently under-explained in-app.

- **Can fix after launch**
  - Improve legal terminology from generic `License Agreement` to clearer Apple Standard EULA labeling.
  - Reduce review-only operational instructions and internal nomenclature in docs.

## 12. FILES / FLOWS REVIEWED

- Project and capability/configuration:
  - [Loom Life Manager.xcodeproj/project.pbxproj](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/Loom%20Life%20Manager.xcodeproj/project.pbxproj)
  - [loom/Info.plist](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Info.plist)
  - [loom/loom.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loom.entitlements)
  - [ShareIntoLoomExtension/Info.plist](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/ShareIntoLoomExtension/Info.plist)
  - [ShareIntoLoomExtension/ShareIntoLoomExtension.entitlements](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/ShareIntoLoomExtension/ShareIntoLoomExtension.entitlements)

- App shell, onboarding, account, and review/demo logic:
  - [loom/loomApp.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/loomApp.swift)
  - [loom/App/RootGateView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/App/RootGateView.swift)
  - [loom/App/UserSessionStore.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/App/UserSessionStore.swift)
  - [loom/Onboarding/AccountStepView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Onboarding/AccountStepView.swift)
  - [loom/App/LoomDemoWorkspaceSeeder.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/App/LoomDemoWorkspaceSeeder.swift)
  - [loom/AccountView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AccountView.swift)
  - [docs/app-review-attachment.rtf](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/docs/app-review-attachment.rtf)

- AI, privacy, commerce, integrations, and polish:
  - [loom/LoomAIService.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoomAIService.swift)
  - [loom/LoomAIChatProvider.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoomAIChatProvider.swift)
  - [loom/AppleIntelligenceSupport.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AppleIntelligenceSupport.swift)
  - [loom/worker.js](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/worker.js)
  - [loom/FirestorePersonalizationRepository.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/FirestorePersonalizationRepository.swift)
  - [loom/AppFeedbackService.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/AppFeedbackService.swift)
  - [loom/Analytics/AnalyticsCollectionPolicy.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Analytics/AnalyticsCollectionPolicy.swift)
  - [loom/Paywall/SubscriptionPlan.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/SubscriptionPlan.swift)
  - [loom/Paywall/PurchaseManager.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/PurchaseManager.swift)
  - [loom/Paywall/LegalLinksView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Paywall/LegalLinksView.swift)
  - [loom/CaptureView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/CaptureView.swift)
  - [loom/PlanView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/PlanView.swift)
  - [loom/ActionView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/ActionView.swift)
  - [loom/FulfillmentView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/FulfillmentView.swift)
  - [loom/Models.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/Models.swift)
  - [loom/ObjectivesAddViewChart.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/ObjectivesAddViewChart.swift)
  - [loom/LoomNotifications.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoomNotifications.swift)
  - [loom/LoadingSplashView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/LoadingSplashView.swift)
  - [loom/DiagnosticInsightsView.swift](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/loom/DiagnosticInsightsView.swift)
  - [docs/index.txt](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/docs/index.txt)
  - [docs/support.html](/Users/spencer.daugherty/Developer/Loom%20Life%20Manager/docs/support.html)
