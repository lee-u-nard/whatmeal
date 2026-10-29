# Stage 12 — restart, terminal feed recovery and rapid account switching

Continue Stage 11; preserve all earlier work and failures. Only demo-whatmeal-audit Auth/Firestore emulators and the dedicated local AOSP AVD are authorized. No production access, live AI, paid services, deployment or schema/rule changes.

## Reproduction and repairs

- feed-reproduced.*: exit 1, 0 passed/4 failed. Pantry and dietary-profile feeds notified observers before installing the new account's authorized root, and notified an empty result before installing their safe listener error. These synchronous observations are not proof of a live cross-account data disclosure.
- Both repositories now resolve membership/root and error state before publishing. Added injectable account/household/feed boundaries while keeping the same production SDK queries and permission checks. Dispose detaches Auth, household and feed sources and invalidates outstanding callbacks.
- feed-fixed.*: exit 0, 12 tests passed: six new feed regressions plus existing shared meal/pantry and editor recovery coverage. New cases include terminal error plus stream close, explicit Retry opening a new feed, A-B-A, late old-feed events, synchronous scope/error observations and source detachment.
- Initial fixture generation failed before writing its target (JavaScript interpolation); no app source was changed by that command. analyze-initial.* contains two style infos. analyze-fixture.* contains missing shared_preferences errors; removed that dependency idea. The integration fixture uses only an app-private file holding disposable test identifiers, never passwords or tokens. analyze-fixed.* passed, no issues.

## Planned direct Android evidence

The same debug integration APK runs twice with --keep-app-running so Flutter does not uninstall its native Auth/session/cache. ADB force-stops only com.example.whatmeal.local between phases; the fixed Firestore relay is offline before the second launch. Auth emulator remains available. This is specifically a Firestore-offline process restart, not a whole-device offline or OS reboot claim.

Fixture preparation uses registration, verification, household, pantry, grocery and profile UI controls. Email verification action lookup uses only local Auth REST and actual SDK completion. After cached UI checks, the test restores the relay and requires an authorized server read. Isolated custom repository feeds request a forbidden demo path to obtain actual SDK permission-denied terminal errors, then Retry binds the authorized household query. This tests repository/SDK recovery, not an end-to-end Retry-button press for a naturally revoked household. Three A-B-A cycles use actual native Auth SDK transitions and inspect repository isolation plus final UI. They are not user tapping speed or simultaneous-device evidence.

Final results and exact commands will be appended after execution. Interrupted or partial workflows will not be counted as passes.
## Completed direct Android evidence

- build-scroll-fixed.* exit0,55.4s; same integration target/defines, AVD stopped, Gradle stopped afterward. Only the fixture's ordinary scrolling changed. First integration binary remains at build/stage12/restart-integration-first.apk.
- android-prepare-fixed.* exit0,52s, one preparation test/four checkpoints (framework +2 includes teardown). Creates/verifies two accounts through UI, creates household/pantry/profile/manual grocery through UI, returns to owner and confirms cached data. App data was cleared only before preparation, never between the passing phases.
- process-restart.json proves original process present, force-stop exit0, process absent afterward, appDataCleared=false, relayOnline=false, same APK hash, and Auth backend available. Integration APK E068C75D012ED37FD509F93FCF8AFECD50747464B25CE512C3081D7A092F53C6.
- android-offline-restart.* exit0,24s, one recovery test/four checkpoints. Actual Android SDK/UI restored authenticated household/pantry/grocery/profile data from persistent cache with the fixed Firestore relay blocked. SDK logged backend timeout/offline mode. After restoring relay, authorized Source.server read passed. The two real SDK forbidden-path listeners each returned permission-denied; explicit repository Retry opened authorized feeds and restored the expected records. Three rapid native Auth SDK A-logout-B-logout-A cycles cleared old data and restored owner UI. Final screenshot android-complete.png visually inspected, no ANR (restart-anr.txt). Relay returned online, dropped1.

The initial preparation failure remains a failed test (android-prepare.*, three checkpoints), not a pass. It waited for a below-fold lazy profile card without scrolling; prepare-progress2.png showed the profile page and absent off-screen card. Fixed fixture scrolls normally without relaxing the expected text/data or bypassing permissions. The first passing preparation and second passing restart are separate tests, not eight independent test cases.

## Evidence boundaries and open work

This is Firestore-offline process restart, not whole-device offline, OS reboot, offline sign-in, lost disk cache, offline edits or queued transaction support. The Auth emulator remained reachable. Cache availability demonstrates previously authorized cached reads, not fresh server authorization while offline; device/account security and later server revocation still apply. No remote membership revocation during outage was tested.

Terminal permission tests use deliberately injected query boundaries with actual Android Firestore streams and unchanged rules, then invoke the repository Retry method. They do not establish an end-to-end visible Retry-button press after naturally revoked membership. General Auth profile, groceries, saved-plan, provider-settings and notification terminal recovery still need their own direct device cases. Rapid switching uses sequential SDK transitions (three cycles), not overlapping UI submissions or simultaneous devices. Existing Stage9 UI household/rejoin and Stage11 account recovery evidence remains intact.

The original 65 security cases/rules are byte-for-byte unchanged by protected hashes; their Stage11 passing rerun is retained rather than repeated. No schema, backend, permission or migration changes. Only demo-whatmeal-audit is approved, via firebase.audit.json, android/app/src/local/google-services.json and guarded lib/main.dart. No non-production live-AI project is configured/approved. No production data was read, modified, migrated or deployed; no live AI, push, paid service, Cloud Function or signing-secret operation occurred.

## Files changed in this continuation

- lib/features/pantry/data/pantry_repository.dart and lib/features/profile/data/family_member_repository.dart: atomic account/root/error publication, scoped dependency boundaries, proper subscription/listener disposal; unchanged SDK collection order and write permission checks. Mapping now runs inside the stream pipeline so parsing failures reach the safe feed-error handler.
- test/scoped_feed_recovery_test.dart: six new account/terminal stream regressions.
- integration_test/stage12_restart_test.dart, test_driver/stage12_restart.dart: app-private test identifiers, two-phase process-restart fixture, real SDK denial/retry and rapid native Auth transitions; only local flavor/demo permitted.
- audit/stage12/*, WHATMEAL_FUNCTIONALITY.md and latest tester links: bounded evidence, all attempts and handoff. Earlier work remains preserved.
## Final checks and standalone tester

flutter-tests.*: exit0, **225 passed**,1:13 (six new cases; Stage11's219 preserved). flutter-analyze.*: exit0, **no issues**,48.3s. No app source changed after the full suite. git diff --check and final check both exited0; pre-existing LF/CRLF notices only. All five protected hashes remain unchanged, including rules/security suite and local native/Dart guards. No need to rerun the unchanged65-case suite; Stage11's verified passing rerun remains the security baseline.

build-tester.*: exit0,82.8s,55.2MB/**57879145bytes**. apk-verification.*: exit0. Package **com.example.whatmeal.local**, version1.0.0/code1, minSDK24/target36, native Firebase **demo-whatmeal-audit**; Dart local guard unchanged. Firestore8180/Auth9099, no relay define. Existing debug tester certificate reused (SHA256371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb), v2 signature verified. Native HTTP deny-default and loopback-only allowance plus FCM/analytics disabled verified. No production key.properties present, no keystore/secret generated or exposed.

Artifact **build/stage12/whatmeal-local-tester.apk**; SHA256 **203BCA4E98C3FE4E022E1BA110DBF6EEC8E74714C940174EAB91ACA83BB311A0**. Tester install/reset/cold-start all exit0; COLD TotalTime**1141ms**. Original-branded Sign In screenshot tester-startup.png visually inspected; focus matches local app, no ANR. Only the isolated .local tester's disposable data was cleared after completing/preserving restart evidence. This is a local emulator tester, not production readiness or release approval.

The dedicated AVD, own relay and demo backend were stopped intentionally after verification. Backend interrupted exit1 is service cleanup, not a failed acceptance test. Final listener check found none on8180/8181/8182/9099/5564/5565. Installed tester remains on AVD disk; use TESTER.md to restart services before manual use. Earlier APKs and failed/interrupted evidence are preserved.

## Prioritized continuation

1. Add direct terminal-error recovery cases for canonical Auth profile, active grocery parent/items, nested saved plans, settings and notification feeds. Auth profile currently provides fallback-only data on listener error; explicit recovery/feedback needs its own scoped implementation and tests. Exercise visible Retry controls after natural access changes, rather than claiming the injected query test covers those UI flows.
2. Test switching while reads/writes/edits are delayed or failing, including obsolete completion after returning to the same UID. Current Stage12 Android transitions are rapid but sequential and connected after the restart phase.
3. Broaden offline behavior to whole-device offline/restart, cold cache, mutations, remote removal during outage, and OS process/boot recovery. Do not treat cached membership as fresh online authorization. Keep all tests isolated and preserve failure evidence.
4. Add a second isolated device for concurrent household writes/listener behavior. Current single AVD, two accounts and prior backend evidence do not certify simultaneous devices.
5. Live AI awaits a separately approved test project/configuration; native push needs a trusted sender/device plan. Production signing, credential rotation/storage migration, migration and deployment remain separately approved future work. Do not use production as a test substitute.
