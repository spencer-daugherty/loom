import { ensureUser, requireEnv } from "./_admin.mjs";

const email = requireEnv("TEST_DEMO_EMAIL", "demo@loomlife.us");
const password = requireEnv("TEST_DEMO_PASSWORD");

const user = await ensureUser(email, password);
console.log(`test demo user ready: ${user.uid} (${user.email})`);
