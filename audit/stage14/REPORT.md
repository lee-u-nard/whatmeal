# Stage 14 — notification recovery and account isolation

Final result: **243 Flutter tests passed; analysis clean; actual Android inbox/settings workflow passed all 9 checkpoints; rebuilt local tester installed and cold-started successfully.** Four grouped notification findings addressed. No live AI, native push or production certification.

Continuation from Stage 13. Preserve all previous work and failed evidence. Only demo-whatmeal-audit local emulators are authorized. Live AI stays pending; no production access, rules changes, cloud deployment, paid services, or signing changes.

Target: notification terminal listener recovery, consistent account/household state, disposal, read-state/routing guards; direct Android notification and settings Retry acceptance where feasible. Existing 65 security cases remain unchanged and retain prior passing evidence. New injection boundaries use the same default SDK queries and permissions.

Evidence will distinguish Flutter mock tests, actual SDK/emulator UI tests, and controlled delays. No native push or live AI claim.
## Reproduced defects and scoped repairs

1. Notification account reset notified listeners before clearing prior errors/loading state. Regression failed; account/household state is now published consistently.
2. Notification Retry incremented the account-session version. Regression failed (1 became 2); separate personal/shared feed generations now reopen listeners without invalidating same-session navigation.
3. Notification disposal left account/household/feed subscriptions active. Regression failed; owned subscriptions and pending-navigation notifier are now disposed; terminal feeds cancel on error.
4. Source-traced stale notification actions: captured page actions lacked the opening session and household departure did not invalidate queued routing. Capture/check account-and-household session for read/mark-all/open; clear queued navigation on account/household changes. A-B-A and retained callback regressions cover rejection before writes/routes.

The first fixture compile failed because this project's Dart language level treats repeated `_` parameters as duplicate declarations. Retained in notification-reproduced.*; corrected fixture then reproduced 3 actual failures in notification-reproduced-valid.*. notification-fixed.* passed7; recovery-expanded.* passed12 before the additional retained callback case. Fixture-generation wrapper failed before writing the Android file (JavaScript interpolation), then the literal file construction succeeded. A non-escalated Dart formatter failed in the constrained environment; escalated formatter passed. Initial analysis reported one protected-member warning in a test; fixed with a subclass public test accessor rather than suppression.

Changes so far: notification_service.dart (injection of existing account/query boundaries; production singleton queries unchanged, local native notifications remain disabled; state/session/disposal fixes); notifications_page.dart (optional service and captured-session actions); notification_recovery_test.dart (six new cases); stage14 Android test/driver; this evidence. No security rules/schema changes. Live AI remains pending.

## Verification scope

Full Flutter suite:243passed, exit0,1:05 (six new notification cases versus Stage13). Clean analysis:exit0,3.3s after a redundant test import was removed. No product behavior changed after that suite. These are mock/controlled stream and widget tests, not live Firebase/device proof. Android acceptance is recorded separately below when executed.

Remaining limits: native push/FCM permission and initialization/token failure recovery, real email delivery, live AI, physical/simultaneous devices, OS-wide offline/reboot, native Auth RPC overlap and already-dispatched writes remain outside this batch. Only demo-whatmeal-audit is approved, configured through firebase.audit.json, android/app/src/local/google-services.json and guarded lib/main.dart. No live-AI project has been approved. No production data read/modified, migration or deployment.

## Android acceptance — executed

build-integration.* exit0,62.5s. Dedicated AVD booted (emulator-reported26.6s), native project checked as demo-whatmeal-audit before installing. android-inbox.* exit0,42s, one combined UI workflow with9checkpoints (framework +2 includes teardown, not two independent workflows). android-phases.json records4 captured permission-denied observations; these are not four new security acceptance cases. Registration/email verification used ordinary UI plus local Auth action handling. Household creation used ordinary UI. Notifications and settings pages used injected existing SDK query boundaries: forbidden personal/household/settings queries produced actual SDK permission denials and visible Retry reopened authorized queries.

UI Mark All Read persisted the personal record and own shared receipt, verified with Source.server; native SDK A-B-A restored read state, cleared queued routes and rejected obsolete actions. Provider configuration used no keys and only local model metadata; saved metadata stayed scoped and returned to A. No live provider request or model-compatibility claim. notification-recovered.png was captured before teardown and visually inspected: personal and shared entries present, both read; no error banner. Android reports no ANR. The injected page harness uses MaterialApp; standalone branded startup is verified separately.

Existing singleton subscriptions logged permission denials during real sign-out transitions; these were retained, not suppressed. The captured4 figure concerns only controlled fixture sources. No permission exception was bypassed, no rules weakened, and no native push delivered. Native FCM stays disabled in local flavor. AVD stopped after acceptance before release-mode tester build.

## Findings classification and important files

Four grouped findings addressed: three MEDIUM (inconsistent reset publication; Retry invalidating same-session operations; stale notification routes/read actions across account or household changes) and one LOW (owned listener disposal). The first, second and disposal defects were reproduced before repair; stale actions were source-traced and covered after repair. This is not a claim of a reproduced production data leak.

- lib/core/services/notification_service.dart: existing SDK-boundary injection; separate feed versus account/household generations; consistent reset; terminal cancellation, retry and owned cleanup; scoped read operations; queued navigation clearing. Production default SDK paths/order/limits and local native-notification safeguards preserved.
- lib/features/notifications/pages/notifications_page.dart: optional test service, opening-session capture for read/open/mark-all; post-await routing guard retained.
- test/notification_recovery_test.dart: six new mock/widget cases. integration_test/stage14_inbox_settings_test.dart and test_driver/stage14_inbox.dart: actual Android UI/SDK acceptance and pre-teardown screenshot.
- audit/stage14/, WHATMEAL_FUNCTIONALITY.md and latest README/tester links: evidence and remaining limitations. Historical work/failed artifacts preserved. No database schema, rules/indexes, branding or unrelated feature changes.

Prioritized continuation: (1) household/role and receipt-listener terminal variants, removal during outage, concurrent native Auth requests; (2) native notification initialization/permission/token lifecycle recovery with isolated device capability and trusted sender, retaining no-live-push claims until tested; (3) simultaneous-device/OS-wide offline coverage; (4) live AI only after explicit non-production project approval; (5) owner-controlled production signing, credential/storage decision, migration and deployment under separate approval. Existing client checks cannot cancel already-dispatched SDK requests.

## Updated standalone tester

Release-mode local build exited0,79.1s. Artifact `build/stage14/whatmeal-local-tester.apk`,57,895,529 bytes, SHA-256 `81BA3903697881E2173E577EC46827DDD693379E101971A5FF01E9249466772D`. Package `com.example.whatmeal.local`, version1.0.0/code1,min24/target36; native/Dart project `demo-whatmeal-audit`. Verifier exited0, including unchanged local network safeguards and existing debug certificate. No production signing secret created/read/printed; android/key.properties absent.

Install, disposable local-app reset and cold-start each exited0. Android reported COLD,TotalTime1156ms. tester-startup.png was visually inspected and shows original WhatMeal Sign In branding; local package has focus, no ANR since boot. This is separate runtime evidence, not inference from a successful build. The dedicated AVD and demo backend were intentionally stopped afterward. Backend wrapper exit1 reflects deliberate interrupt during cleanup, not a failed acceptance test. Production was not accessed, modified, migrated or deployed.

Final consistency:89 unique requirements, all5 protected files unchanged,10 authoritative child exit files0, APK hash matched, diff check0. cleanup-ports.json confirms dedicated ports8180/8181/8182/9099/5564/5565 closed. No unrelated process stopped.
