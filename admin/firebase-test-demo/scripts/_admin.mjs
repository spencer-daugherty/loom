import fs from "node:fs";
import admin from "firebase-admin";

let cachedApp = null;

export function requireEnv(name, fallback = "") {
  const value = (process.env[name] ?? fallback).trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function getAdminApp() {
  if (cachedApp) return cachedApp;

  const serviceAccountPath = requireEnv("FIREBASE_SERVICE_ACCOUNT_JSON");
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));

  cachedApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  return cachedApp;
}

export function getAuth() {
  return admin.auth(getAdminApp());
}

export function getFirestore() {
  return admin.firestore(getAdminApp());
}

export async function ensureUser(email, password) {
  const auth = getAuth();
  try {
    return await auth.getUserByEmail(email);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
    return await auth.createUser({
      email,
      password,
      emailVerified: true
    });
  }
}
