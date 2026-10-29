# Built-in Gemini: read-only Firebase preflight — October 26, 2026

Project `whatmeal-101`, Android app `com.example.whatmeal`. Only configuration metadata was read using the existing Firebase Tools login; no user records, inference, API enabling, registration, settings updates, deployment or billing change occurred.

Confirmed by GET responses:

- Firebase App Check API: ENABLED.
- Firebase AI Logic API (`firebasevertexai.googleapis.com`): ENABLED.
- Gemini Developer API (`generativelanguage.googleapis.com`): ENABLED.
- Play Integrity API (`playintegrity.googleapis.com`): **DISABLED**.
- Billing: **disabled**.
- App Check Play Integrity config: `allowUnrecognizedVersion: false`; current minimum device integrity `NO_INTEGRITY`.
- Android app SHA certificate-list API: **0 SHA-256 certificates**, so the certificate signing the delivered APK is unregistered.

These are confirmed attestation configuration blockers for the delivered APK installed outside Google Play. The release uses Play Integrity; Firebase AI SDK 2.3.0 obtains its App Check token before inference. The old screenshot concealed the raw Firebase plugin/code. This preflight explains incompatible configuration, but does not establish a successful token exchange or live generation on the user's device.

Proposed owner-approved correction, **not performed**:

1. Enable only the Play Integrity API for this project.
2. Register the delivered APK's existing public signing-certificate SHA-256 against the existing Android app. Do not change or generate signing keys.
3. Configure Play Integrity for the actual off-Play APK distribution: allow unrecognized versions and require `DEVICE_INTEGRITY`, consistent with Firebase's documented off-Play setup. Preserve App Check enforcement; no debug-token bypass, Firestore rules change, billing upgrade or data migration.
4. Read back the exact changes and retest the phone connection and bounded meal generation; do not claim success before actual results.

Configuration guidance: [Android Play Integrity setup and distribution requirements](https://firebase.google.com/docs/app-check/android/play-integrity-provider), [PlayIntegrityConfig schema](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.playIntegrityConfig), [Android certificate-list schema](https://firebase.google.com/docs/reference/firebase-management/rest/v1beta1/projects.androidApps.sha/list).

Evidence: `build/free-ai-repair-20261026-5a8b9a94/online-ai-service-status.json`; the local probe uses GET metadata only. An initial probe incorrectly looked for certificate hashes on PlayIntegrityConfig; it is retained as `online-ai-status-before-certificate-schema-correction.json` and must not be used for the certificate finding. The final finding uses the documented Android app `/sha` endpoint. No server-side change is authorized by this report; the user's earlier boundary requires explicit approval before production settings changes.
