# Firebase configuration

The app expects a real Firebase iOS config at:

```text
loom/GoogleService-Info.plist
```

That file is intentionally ignored by git. Use `loom/GoogleService-Info.plist.example` as the shape reference, then download a fresh iOS plist from Firebase Console for bundle ID `srd.loom`.

After a GitHub secret scanning alert:

1. Rotate the exposed Google API key in Google Cloud Console.
2. Restrict the replacement key to the iOS app bundle ID and App Store signing certificate SHA-1/SHA-256 where applicable.
3. Restrict allowed APIs to only the Firebase/Google APIs Loom actually uses.
4. Replace the local `loom/GoogleService-Info.plist` with the new downloaded plist.
5. Do not commit the real plist.

The root-level `GoogleService-Info.plist` fallback should not be used for new setup.
