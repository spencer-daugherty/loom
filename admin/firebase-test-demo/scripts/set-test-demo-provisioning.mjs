import admin from "firebase-admin";
import { ensureUser, getFirestore, requireEnv } from "./_admin.mjs";

const email = requireEnv("TEST_DEMO_EMAIL", "demo@loomlife.us");
const password = requireEnv("TEST_DEMO_PASSWORD");
const templateId = (process.env.TEST_DEMO_TEMPLATE_ID ?? "legacy-demo-v1").trim();
const templateVersion = Number.parseInt(process.env.TEST_DEMO_TEMPLATE_VERSION ?? "1", 10);
const resetToken = Number.parseInt(process.env.TEST_DEMO_RESET_TOKEN ?? "1", 10);
const grantedPlan = (process.env.TEST_DEMO_GRANTED_PLAN ?? "monthly").trim();

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
      templateId,
      templateVersion,
      resetToken,
      grantedPlan,
      autoCompleteGates: true,
      alertTitle: "Demo Account",
      alertMessage: "This account loads preserved sample data from Firebase-backed demo provisioning.",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

console.log(`updated demo provisioning for ${user.email}`);
