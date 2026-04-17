# Loom App Store Review Audit

Date reviewed: 2026-04-17  
Project reviewed: Loom iOS app

## Executive Verdict

Loom is in a better review posture than the prior audit suggested, but it is **not fully App Review-ready yet**.

The biggest remaining problems are:

1. The shipping app still contains **special demo / review account logic** and a Firebase-controlled demo workspace path.
2. The production app still exposes a **hidden developer surface** behind a hardcoded PIN.
3. Subscription UI and disclosures still rely on **time-limited promotional claims** that must exactly match the live App Store Connect / StoreKit configuration.

The privacy-policy source and support page are materially better than before. Old findings about missing Photos usage strings and active Google Tasks / Microsoft To Do sync are **no longer current** in this repo state.

## High-Risk Approval Blockers

1. **Shipping build still contains special demo / review account logic, while the review attachment says it does not.**  
Why Apple may care: App Review is sensitive to hidden review modes, demo accounts, seeded datasets, and reviewer instructions that do not match the shipped binary. A repo that says “no special review or demo account logic” while the app still contains an enabled demo-provisioning path is a credibility and approval risk.  
Evidence in repo: [app-review-attachment.rtf](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/app-review-attachment.rtf:16>) says the shipping build does not include special review or demo account logic; [InternalDemoProvisioning.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/InternalDemoProvisioning.swift:7>) hardcodes `LoomInternalDemoMode.isEnabled = true`; [AccountStepView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Onboarding/AccountStepView.swift:595>) enables `LoomSpecialAccountWorkspace.reviewDemo` when Firebase provisioning says to do so; [LoomDemoWorkspaceSeeder.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/App/LoomDemoWorkspaceSeeder.swift:5>) defines the `demo@loomlife.us` review-demo workspace; [firebase-test-demo-runbook.md](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/firebase-test-demo-runbook.md:1>) documents the seeded demo account and provisioning flow.  
Recommended fix: Remove this path from App Store builds entirely, or move it behind a non-shipping build flag that is disabled for release archives. Then update the review attachment so it precisely matches the shipped behavior.

2. **Production account UI still exposes a hidden developer page gated by account name and a hardcoded PIN.**  
Why Apple may care: Hidden admin or debug controls in production builds can be treated as undisclosed functionality, especially when they toggle troubleshooting, AI debug, paywall behavior, or demo resets.  
Evidence in repo: [AccountView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AccountView.swift:919>) shows a `Developer` button when the account name is `Spencer`; [AccountView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AccountView.swift:1022>) unlocks the page with PIN `0927`; [AccountView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AccountView.swift:1040>) includes `Reset demo@loomlife.us`; [AccountView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AccountView.swift:1075>) includes `LoomAI Debug` and other feature flags.  
Recommended fix: Strip the developer page and unlock logic from release builds, or gate it with a compile-time internal build flag that is not present in App Store submissions.

3. **Subscription marketing still uses promotional countdown / lock-in claims that can drift from the actual offer.**  
Why Apple may care: Subscription review is strict about pricing clarity, trial claims, and time-limited offers. If the copy shown in-app diverges from the live product metadata or offer configuration even slightly, review can fail.  
Evidence in repo: [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:54>) uses `Founding Member (Lifetime)`; [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:56>) uses `Annual (Early Adopter)`; [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:123>) advertises a `10-day free trial`; [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:139>) says `price-lock for life`; [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:168>) and [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:170>) hardcode May 31, 2026 and June 30, 2026 offer deadlines; [PaywallView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/PaywallView.swift:152>) uses `Purchase Founding Member (Lifetime)?`.  
Recommended fix: Either simplify the copy to durable StoreKit-safe language, or verify every label, date, countdown, and trial statement against the exact live App Store Connect configuration before submission.

## Medium-Risk Review Concerns

1. **Privacy docs say Loom no longer relies on Loom-hosted remote AI processing, but the app target still contains worker-client code and a temporary worker debug screen.**  
Why Apple may care: Reviewers expect privacy disclosures to match the shipped binary. Even if this path is not prominently surfaced in the UI, compiled worker endpoint code and OpenAI fallback parsing can undermine the claim that all AI is now Apple Intelligence or local-only.  
Evidence in repo: [index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:60>) says Loom now relies on Apple Intelligence or local on-device logic rather than Loom-hosted remote AI processing; [privacy-policy-input-summary.md](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/privacy-policy-input-summary.md:90>) says unsupported devices use local compatibility logic instead of Loom-hosted remote AI; [LoomAIService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIService.swift:5>) still points to `loom-ai-minimal.spence0927.workers.dev`; [LoomAIService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIService.swift:445>) still contains OpenAI fallback parsing types; [TemporaryVisionAutoWriteDebugView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/TemporaryVisionAutoWriteDebugView.swift:8>) describes a raw worker diagnostics screen; [TemporaryVisionAutoWriteDebugView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/TemporaryVisionAutoWriteDebugView.swift:89>) still contains live worker endpoints.  
Recommended fix: Remove the worker client and temporary debug screen from the app target, or explicitly keep them out of release builds. Then keep the privacy docs as written. If they must remain in release code, the privacy and review docs need to describe that residual capability accurately.

2. **App feedback sends free-text plus account-linked identifiers to Firestore, which means App Store Connect privacy labels must be exact.**  
Why Apple may care: If App Privacy labels understate transmitted data, Apple can reject even when the hosted policy is otherwise solid.  
Evidence in repo: [AppFeedbackService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AppFeedbackService.swift:61>) includes rating, timestamps, app version, build, and user key; [AppFeedbackService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AppFeedbackService.swift:71>) conditionally includes free-text `details`; [AppFeedbackService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AppFeedbackService.swift:75>) through [AppFeedbackService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AppFeedbackService.swift:87>) include email, name, and auth provider when available; [AppFeedbackService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AppFeedbackService.swift:98>) writes to Firestore `app_feedback`; [index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:14>) and [index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:75>) disclose support/feedback retention, which is directionally correct.  
Recommended fix: Verify the App Store Connect privacy questionnaire covers contact info, identifiers, diagnostics/analytics, and user content submitted through feedback.

3. **The review-attachment guidance is cleaner than before, but it is now stale relative to the real app behavior.**  
Why Apple may care: Review notes that incorrectly describe the sign-in / demo path create friction and can cause avoidable rejection or requests for clarification.  
Evidence in repo: [app-review-attachment.rtf](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/app-review-attachment.rtf:10>) says to use the standard sign-in flow; [app-review-attachment.rtf](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/app-review-attachment.rtf:16>) says there is no special review or demo account logic; [firebase-test-demo-runbook.md](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/firebase-test-demo-runbook.md:58>) still explicitly describes using the demo account for App Review if needed.  
Recommended fix: Replace the attachment with exact current review steps, or fully remove the demo/review code so the attachment becomes true again.

## Low-Risk Trust / Polish Issues

1. **Stale retired-integration configuration keys remain in Info.plist.**  
Why Apple may care: Usually this is not a rejection issue by itself, but dead Google / Microsoft OAuth placeholders can create confusion if the integrations are supposed to be retired.  
Evidence in repo: [Info.plist](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Info.plist:25>) through [Info.plist](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Info.plist:34>) still contain empty Google OAuth and Microsoft OAuth keys.  
Recommended fix: Remove unused Info.plist keys for retired integrations so the bundle metadata matches the actual feature surface.

2. **Temporary worker-debug comments and artifacts still describe branches that no longer appear to exist.**  
Why Apple may care: This is mostly a maintenance/trust issue, but it makes the repo and audit story harder to defend.  
Evidence in repo: [TemporaryVisionAutoWriteDebugView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/TemporaryVisionAutoWriteDebugView.swift:8>) says to delete a `showTemporaryVisionAutoWriteDebugPage` branch in `loomApp.swift`, but repo search no longer finds that branch.  
Recommended fix: Delete the stale debug file entirely or isolate it in a non-release target.

## Privacy / Data Disclosure Audit

1. **The hosted privacy-policy source is substantially improved and generally aligned with the current code.**  
Why Apple may care: This is the main positive change since the prior audit. It reduces the risk of review confusion around retired integrations and AI handling.  
Evidence in repo: [index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:53>) through [index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:60>) now describe Apple, Firebase, Apple Intelligence, and local compatibility behavior; [privacy-policy-input-summary.md](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/privacy-policy-input-summary.md:87>) through [privacy-policy-input-summary.md](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/privacy-policy-input-summary.md:94>) mirror that AI summary; [support.html](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/support.html:649>) through [support.html](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/support.html:689>) correctly link to the hosted privacy policy and support path.  
Recommended fix: Keep this direction, but do not overstate the remote-AI retirement until the compiled worker artifacts are removed from the release target.

2. **Code-vs-policy cross-check: personalization sync and feedback transmission are disclosed, but retention and App Privacy labels still need manual confirmation.**  
Why Apple may care: Review will look at both the hosted policy and the App Store Connect privacy questionnaire, not just the repo docs.  
Evidence in repo: [FirestorePersonalizationRepository.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/FirestorePersonalizationRepository.swift:23>) through [FirestorePersonalizationRepository.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/FirestorePersonalizationRepository.swift:32>) read Firestore personalization state; [FirestorePersonalizationRepository.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/FirestorePersonalizationRepository.swift:55>) through [FirestorePersonalizationRepository.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/FirestorePersonalizationRepository.swift:74>) write current and history snapshots; [FirestorePersonalizationRepository.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/FirestorePersonalizationRepository.swift:89>) through [FirestorePersonalizationRepository.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/FirestorePersonalizationRepository.swift:103>) clear that state; [index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:73>) through [index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:76>) disclose retention in general terms.  
Recommended fix: Confirm App Store Connect labels match these behaviors exactly. The repo cannot verify the live App Privacy answers.

## Account / Auth / Deletion Audit

1. **Core account flows look directionally compliant.**  
Why Apple may care: Sign in with Apple support and in-app deletion are common review checkpoints.  
Evidence in repo: [loom.entitlements](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/loom.entitlements:5>) enables Sign in with Apple; [AccountView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AccountView.swift:2479>) through [AccountView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AccountView.swift:2507>) perform account deletion; [AccountView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AccountView.swift:2572>) through [AccountView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/AccountView.swift:2646>) reauthenticate and revoke Apple authorization when needed; [support.html](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/support.html:602>) through [support.html](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/support.html:606>) correctly describe Apple and Google sign-in support.  
Recommended fix: Keep these flows, but make sure App Store Connect review notes no longer reference any internal demo account behavior unless that is truly intended.

## Subscriptions / IAP Audit

1. **Restore flow and StoreKit entitlement handling are present and look normal.**  
Why Apple may care: This is a positive baseline.  
Evidence in repo: [PurchaseManager.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/PurchaseManager.swift:266>) through [PurchaseManager.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/PurchaseManager.swift:284>) restore purchases via `AppStore.sync()`; [PaywallView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/PaywallView.swift:371>) through [PaywallView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/PaywallView.swift:397>) expose a visible restore path; [support.html](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/support.html:559>) through [support.html](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/support.html:561>) direct users to restore purchases first.  
Recommended fix: No change needed here beyond keeping the restore path prominent.

2. **The risky part is not restore handling; it is the promotional copy.**  
Why Apple may care: If the offer language is even slightly inaccurate at review time, the IAP flow becomes a review risk.  
Evidence in repo: [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:77>) through [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:89>) include price text and countdown behavior; [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:123>) through [SubscriptionPlan.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/SubscriptionPlan.swift:139>) include trial and price-lock claims; [PurchaseManager.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/PurchaseManager.swift:462>) through [PurchaseManager.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Paywall/PurchaseManager.swift:466>) repeat the June 30, 2026 pricing-lock language.  
Recommended fix: Use evergreen subscription copy unless there is a strong reason not to.

## Permissions / Entitlements Audit

1. **The old Photos permission finding is stale; the current repo now has the needed strings.**  
Why Apple may care: This is a positive correction relative to the previous audit.  
Evidence in repo: [Info.plist](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Info.plist:38>) includes camera usage; [Info.plist](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Info.plist:40>) includes photo-library usage; [Info.plist](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Info.plist:42>) includes add-only Photos save usage.  
Recommended fix: Keep these strings synchronized with the actual user-facing flows.

2. **Health, Reminders, notifications, and app-group usage look broadly consistent with the current feature set.**  
Why Apple may care: These are common permission-review points.  
Evidence in repo: [loom.entitlements](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/loom.entitlements:13>) enables HealthKit; [project.pbxproj](</Users/spencer.daugherty/Developer/Loom Life Manager/Loom Life Manager.xcodeproj/project.pbxproj:441>) and [project.pbxproj](</Users/spencer.daugherty/Developer/Loom Life Manager/Loom Life Manager.xcodeproj/project.pbxproj:442>) define HealthKit and Reminders usage strings; [Models.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/Models.swift:1477>) and [ObjectivesAddViewChart.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/ObjectivesAddViewChart.swift:210>) request Health read authorization with `toShare: nil`; [LoomNotifications.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomNotifications.swift:125>) requests local notification authorization; repo search did not find `registerForRemoteNotifications`, `remote-notification`, or `aps-environment`; [loom.entitlements](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/loom.entitlements:9>) and [ShareIntoLoomExtension.entitlements](</Users/spencer.daugherty/Developer/Loom Life Manager/ShareIntoLoomExtension/ShareIntoLoomExtension.entitlements:5>) limit the shared entitlement story to the app group used by the share extension.  
Recommended fix: No new blocker found here. Just verify the runtime permission prompts still match the copy.

## AI / Apple Intelligence / Network Audit

1. **Core user-facing AI appears intended to be Apple Intelligence on supported devices plus local compatibility on unsupported devices.**  
Why Apple may care: This is the architecture now described in the privacy-policy sources.  
Evidence in repo: [LoomAIChatProvider.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIChatProvider.swift:17>) defines Apple Intelligence as the suggestion source label; [LoomAIChatProvider.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIChatProvider.swift:79>) chooses between `.appleIntelligence` and `.localCompatibility`; [LoomAIChatView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIChatView.swift:57>) through [LoomAIChatView.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIChatView.swift:58>) present the Apple Intelligence / compatibility status text in the chat UI.  
Recommended fix: Keep the user-facing architecture simple and consistent.

2. **However, the release target still contains network worker code that weakens the “local-only / Apple Intelligence only” story.**  
Why Apple may care: This is the residual risk that still needs cleanup.  
Evidence in repo: [LoomAIChatViewModel.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIChatViewModel.swift:401>) still injects `LoomAIService`; [LoomAIService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIService.swift:5>) and [LoomAIService.swift](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/LoomAIService.swift:6>) still hardcode the worker base URLs; [worker.js](</Users/spencer.daugherty/Developer/Loom Life Manager/loom/worker.js:1947>) still contains OpenAI network calls.  
Recommended fix: Remove these from the app target, or prove they are excluded from release archives and update internal docs to say so.

## Manual App Store Connect Checklist

1. Verify the **App Review notes** no longer imply there is no demo logic if the release binary still contains it.
2. Verify the **App Privacy questionnaire** covers:
   account identifiers, contact info, user content, diagnostics/analytics, Health data, Reminders/task data, photos/camera use, personalization sync, and feedback submissions.
3. Verify the **subscription metadata** in App Store Connect exactly matches the in-app names, trial, renewal, and deadline language.
4. Verify the hosted **Privacy Policy URL** and **Support URL** in App Store Connect match [index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:94>) and [support.html](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/support.html:686>).
5. If any demo account is intentionally used for review, describe it honestly and minimally in App Review Information instead of implying the path does not exist.

## Prioritized Fix Plan

1. Remove or fully release-gate the demo / review workspace path and the hidden developer page.
2. Rewrite `docs/app-review-attachment.rtf` so it exactly matches the shipped app behavior.
3. Simplify or re-verify all paywall offer language against live StoreKit / App Store Connect metadata.
4. Remove worker / OpenAI debug artifacts from the release target so the privacy-policy AI statements become fully true.
5. Re-run this audit after those changes and then manually confirm App Store Connect privacy answers.

## Docs Coverage Appendix

- [docs/app-store-review-audit.md](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/app-store-review-audit.md:1>)  
  Status: replaced by this fresh audit.  
  Checked for: stale legacy findings, current structure, evidence quality.

- [docs/privacy-policy-input-summary.md](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/privacy-policy-input-summary.md:1>)  
  Status: mostly current internal source doc with a few open-question placeholders.  
  Checked for: third-party services, AI architecture, remote storage, permissions, App Privacy follow-ups.

- [docs/index.txt](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/index.txt:1>)  
  Status: largely current and much improved.  
  Checked for: live privacy-policy claims, retired-integration removal, AI wording, retention language, support URL.

- [docs/support.html](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/support.html:520>)  
  Status: current informational support page.  
  Checked for: support path, fallback email, privacy-policy link, sign-in guidance, subscription support guidance.

- [docs/app-review-attachment.rtf](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/app-review-attachment.rtf:1>)  
  Status: stale and risky.  
  Checked for: reviewer instructions, sign-in path, demo/review claims, account-management notes.

- [docs/firebase-test-demo-runbook.md](</Users/spencer.daugherty/Developer/Loom Life Manager/docs/firebase-test-demo-runbook.md:1>)  
  Status: current operational document, but high-risk for review because it confirms the live demo provisioning flow.  
  Checked for: demo-account setup, provisioning path, reset behavior, App Review usage guidance.
