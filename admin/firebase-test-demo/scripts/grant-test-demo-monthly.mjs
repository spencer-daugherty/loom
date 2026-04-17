import admin from "firebase-admin";
import { ensureUser, getFirestore, requireEnv } from "./_admin.mjs";

const email = requireEnv("TEST_DEMO_EMAIL", "demo@loomlife.us");
const password = requireEnv("TEST_DEMO_PASSWORD");

const user = await ensureUser(email, password);
const db = getFirestore();

await db
  .collection("users")
  .document(user.uid)
  .collection("demoProvisioning")
  .document("current")
  .set(
    {
      enabled: true,
      grantedPlan: "monthly",
      autoCompleteGates: true,
      notes: "Internal test demo monthly access",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

console.log(`granted monthly access to ${user.email}`);
