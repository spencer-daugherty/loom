# Firebase demo-account admin tools

These scripts manage the Firebase-backed `demo@loomlife.us` seeded demo account.

## Prerequisites

1. Use the production Firebase project for Loom.
2. Enable Email/Password auth.
3. Generate a service account JSON file.
4. Export these environment variables before running the scripts:

```bash
export FIREBASE_SERVICE_ACCOUNT_JSON="/absolute/path/to/service-account.json"
export TEST_DEMO_EMAIL="demo@loomlife.us"
export TEST_DEMO_PASSWORD="set-a-strong-password"
```

## Install

```bash
cd admin/firebase-test-demo
npm install
```

## Create the demo user

```bash
npm run create:test-demo-user
```

## Grant monthly access

```bash
npm run grant:test-demo-monthly
```

This updates the existing demo provisioning document so `demo@loomlife.us` loads the preserved demo workspace with a monthly demo plan.

## Set demo provisioning

This creates/updates:

- `users/{uid}/demoProvisioning/current`

Example:

```bash
npm run set:test-demo-provisioning
```

Default provisioning created by the script:

- `enabled = true`
- `templateId = legacy-demo-v1`
- `templateVersion = 1`
- `resetToken = 1`
- `grantedPlan = monthly`
- `autoCompleteGates = true`

To force the demo workspace to reset later, rerun the provisioning script with a higher `TEST_DEMO_RESET_TOKEN` value.
