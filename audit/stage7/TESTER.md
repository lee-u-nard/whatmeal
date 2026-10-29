# Isolated tester setup

**Superseded by Stage 8: do not launch the Stage 7 APK.** Stage 8 inspection found that its Dart demo options did not replace the native Google Services resources, which still selected the existing Firebase project. Stage 7 recorded a build and signature check, not a verified isolated startup. The new Android `local` flavor has a distinct `.local` application ID and demo native resources. Use `--flavor local`; see `audit/stage8/TESTER.md`. Historical instructions below describe the old, unverified artifact only.

This stage's tester APK is built with `WHATMEAL_EMULATORS=true` and explicit `WHATMEAL_TESTER_SIGNING=true`. It uses demo-project Auth/Firestore at loopback ports 9099/8180. It is not the production release and must not be described as live AI or FCM verification. No Android device or AVD was available during this stage.

The build's default loopback host supports a USB device through `adb reverse tcp:8180 tcp:8180` and `adb reverse tcp:9099 tcp:9099`. Start both local emulators with project `demo-whatmeal-audit` and `firebase.audit.json`. The Stage 7 runner demonstrates the process-local Java setting needed on this host, but stops the emulators when its tests finish; a manual device session needs them running throughout. Never point this build at a real project. Device startup, native Firebase initialization, cleartext transport and UI behavior still require actual verification.

The APK uses the existing Android application ID. Inspect installed apps before installation; do not replace an existing production installation or erase its local data without approval. Use an isolated test device/profile. Installation was not attempted here.

## Release identity and credentials

- `android/key.properties.example` documents the four signing fields. Supply your existing keystore through ignored `android/key.properties`. Neither keystores nor passwords were created, read, printed or committed in this stage.
- Release packaging requires valid signing configuration or explicit `WHATMEAL_TESTER_SIGNING=true`; debug signing is no longer a silent default. Proper release signing remains pending your signing identity.
- Source no longer contains the bundled Gemini/Unsplash key literals. Gemini continues using Firebase AI or account-provided configuration. Optional Unsplash configuration is supplied via `UNSPLASH_ACCESS_KEY`; absent configuration uses the existing image fallback.
- Build-time defines are extractable from an APK and are not secure storage. Previously exposed credentials and older APK/Git copies still require owner-side rotation/revocation where appropriate. No credential rotation was performed.
- Existing account-stored provider keys were not migrated or deleted. The secure-storage architecture decision in `audit/stage2/KEY_STORAGE_OPTIONS.md` remains open.

## Manual acceptance still needed

Use two isolated devices/accounts to verify registration/email flows, create/invite/join, both-direction SDK stream updates, offline/reconnect, removal/rejoin, meals and grocery recalculation, then account A→B→A with screens/dialogs open. Test duplicate meal IDs in separate plans. Native notification taps/permission recovery need a separate controlled device session; the emulator-only app skips FCM initialization. Live AI requires an explicitly isolated supported project/provider configuration and approved test credentials, not production-data access.
