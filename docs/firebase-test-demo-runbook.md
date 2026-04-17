# Firebase `demo@loomlife.us` demo account runbook

This repo uses `demo@loomlife.us` as the seeded demo account. The app still seeds the actual demo dataset locally, while Firebase controls whether the demo workspace is enabled and when it resets.

## What the app now expects

- Normal email/password sign-in through Firebase Auth
- Optional demo provisioning doc at:
  - `users/{uid}/demoProvisioning/current`

The current implementation activates the demo workspace only when:

1. The signed-in Firebase user has `demoProvisioning/current` with `enabled = true`

## Firebase setup

1. Use the production Firebase project.
2. Enable Email/Password auth.
3. Create a service account and keep the JSON outside the repo.
4. Run the admin scripts in `admin/firebase-test-demo`.

## Required Firestore documents

### Demo provisioning

Path:

`users/{uid}/demoProvisioning/current`

Fields:

- `enabled: true`
- `templateId: "legacy-demo-v1"`
- `templateVersion: 1`
- `resetToken: 1`
- `grantedPlan: "monthly"`
- `autoCompleteGates: true`

## Recommended Firestore rules

Use admin-only writes for the provisioning document.

Example policy intent:

- authenticated user may read `users/{uid}/demoProvisioning/current` only when `request.auth.uid == uid`
- client writes denied for the provisioning path

## Resetting the demo account

To force the demo workspace to reset and reseed:

1. Increase `resetToken`
2. Re-run the provisioning script
3. Sign out and back into `demo@loomlife.us`

The app compares the last applied reset token locally and clears/reseeds the demo workspace when the value changes.

## App Review

If this account is used for App Review, provide the normal login credentials through App Store Connect. Keep the backend live during review.
