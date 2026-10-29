# Stage 11 — password, profile, pantry and recovery follow-up

This continues the preserved Stage 10 checkpoint (206 Flutter tests, 65 security cases, 13 Android grocery/recovery checkpoints and verified local tester). All work uses demo-whatmeal-audit only. No production data, live AI, paid services or deployments are authorized. Stage 10 files and failed-run evidence remain intact.

## Repairs and scope

| Area | Root cause and change | Evidence |
|---|---|---|
| Password identity | Account editor trimmed current/new passwords even though sign-in preserves them. Retain literal values. | Reproduced by widget callback assertions; fixed regression passed. Actual SDK acceptance pending below. |
| Invalid password/name partial save | Name was written before checking current password or reauthenticating. Validate first, require confirmation, change password before name; failed reauthentication retains draft and makes no name write. | Missing/current-wrong-password widget cases reproduced before repair and passed afterward. |
| Partial success and stale editors | A password success followed by name failure could make retry use obsolete credentials; old editors had no session check. Clear completed password fields, show honest partial-success feedback and guard dispatch/continuations by account session. Repository guards before/after awaited Auth operations; fixed safe error types for account actions. | Retained-draft/partial-retry/cancellation/stale-editor widget cases pass. No cross-service atomicity is claimed; already dispatched server operations cannot be cancelled. |
| Profile name authority | Auth-first then Firestore could leave account name changed but canonical profile unsaved. Persist existing canonical profile document first, then sync Auth; explicit partial-sync feedback. Reload preserves canonical profile name. Login already preserves existing profile displayName; old checklist wording claiming unconditional overwrite was stale. | Source tracing; UI login persistence planned. No migration or new schema. |
| Password recovery | Fixed-height Column overflowed a narrow enlarged screen; arbitrary thrown strings could be displayed. Use scrollable existing layout, guarded submit, stronger email validation and fixed safe failure feedback. | Narrow form reproduced; fixed widget passes; retry keeps email and suppresses synthetic private detail. No live email delivery claim. |
| Pantry/dietary draft recovery | Sheets popped before parents dispatched database writes, losing the draft on failure. Await supplied scoped save callbacks inside editors; show safe inline failure, guard duplicate submit/back/close and retain inputs. All existing add/edit entry points use the callback, preserving success feedback. | Injected pending/failure/retry tests pass; same-document pantry metadata regressions retained. |
| Profile/pantry validation and layout | Nonnumeric age silently became 18; range was not validated. Custom pantry category displayed a different selection than its retained value. Dietary heading overflowed at enlarged text. Validate age 0–130, preserve actual category option, bound pantry name/quantity lengths and constrain heading. | Invalid-age/category regressions pass; enlarged dietary editor failed before heading repair, final verification below. |
| Feed recovery | Pantry/dietary failures could look empty with no operative Retry. Added distinct loading/error feedback and guarded resubscription; scoped dietary writes also check post-await generation. | Source review; actual permanent SDK listener-error injection remains unverified. No rule bypass. |

## Execution journal

- account-reproduced.*: exit 1, 0 passed/5 failed (literal passwords, missing-current partial name, failed reauth partial name, stale editor, narrow recovery form).
- account-fixed.*: exit 1, compilation failure caused by an editing-script replacement; retained. account-fixed-final.*: exit 0, 5 passed after syntax repair.
- recovery-focused.*: exit 0, 11 passed (new recovery cases and existing pantry metadata/date cases).
- analyze-initial.*: exit 1, 11 style infos; fixed with scoped lint code. Timestamp confirms analysis completed before the next Flutter test started.
- recovery-expanded.*: exit 1, 11 passed/1 failed: pumpAndSettle timed out because progress animated beneath password confirmation. Confirmation now remains idle until approval; recovery-expanded-fixed.* exit 0, 12 passed.
- profile-layout-reproduced.*: exit 1, 4 passed/1 failed (320px/2x heading overflow). Constrained the existing heading; final full suite follows.
- analyze-device-fixture.*: exit 1, two lint infos/two unnecessary-null assertions in the new fixture/editor; repaired before final checks/build.

All Flutter commands are serialized. Existing Firebase rules, local native manifest/configuration, main.dart guards and Stage 10 security suite are protected by baseline hashes. The existing fixed relay is reused only for local outage testing; standalone builds retain port 8180.

## Remaining limits

No approved non-production live-AI project exists. Password reset's external email action is completed by the actual Firebase SDK using only local emulator action codes; this is not email delivery/browser-link testing. Expired email actions, federated-provider reauthentication, simultaneous devices, terminal SDK listener failures and wider offline/restart behavior require separate evidence. Native push remains disabled. No production signing or credential migration is included.

Final pre-device checks: flutter-tests.* exit 0, **219 tests passed**, 1:02 (13 additional cases versus Stage 10); flutter-analyze.* exit 0, no issues, 26.5 s. build-integration.* exit 0, 62.6 s; Gradle stopped before booting the dedicated AOSP AVD. Existing local tester app data was cleared successfully before installing the debug integration APK (app-reset.* exit 0). No platform/security setting or unrelated app was changed.

First Android run android-recovery.* failed, exit 1, 2:36, after 13 completed checkpoints (android-phases-first.json). Password change/reset, invalid/reused reset actions, persistent name, dietary edit, pantry category/metadata/status/date and second-account isolation/sharing all completed. Pantry retained its edit during a verified relay outage, but quantity did not become 4 kg within the deadline after a single immediate retry. Relay was confirmed online; no ANR. Whether SDK backoff or workspace changes caused it is not yet established. Added a strict authorized Source.server read plus scope diagnostics before retry, preserving the original failure and all write/permission assertions. This probe does not seed data or bypass rules.

## Passing Android acceptance

android-recovery-probe.* passed, exit 0, **2:14**, one combined workflow with **17 checkpoints** (framework +2 includes teardown). android-phases-probe.json records exact phases and recovery diagnostics. All tested actions use actual Flutter Android controls, real Firebase Auth/Firestore SDKs and disposable demo accounts. Typing uses Flutter's deterministic test input handler. Registration verification and password reset action codes come only from local Auth REST; action completion uses the real Auth SDK, without printing codes or passwords.

Verified: incorrect current password retains draft without changing the display name; password/display-name change; old password rejection; literal whitespace-sensitive new-password login; canonical display name retained after login; UI reset request, SDK reset completion, invalid/reused code rejection and reset-password login. The account document contains no password field. This verifies email/password accounts, not federated-provider credentials or expired email actions/live delivery.

Dietary profile edit preserved document identity, original creation timestamp and peanut allergy while updating age/relation and adding Vegan. Pantry edits preserved document ID, exact expiry, author and creation timestamp while changing category/quantity; selected default expiry and all four statuses persisted. A second account saw no previous-account pantry/profile data before joining, then saw authorized shared changes. Pantry and dietary deletion cancellation/confirmation both passed as the invited member.

Recovery diagnostics: relay restored online, then **one real server read returned unavailable** before a subsequent authorized Source.server read succeeded. Household and scope remained unchanged. The ordinary visible-error retry then saved 4 kg with one item identity. This proves the relay's online response alone was insufficient to establish SDK readiness in the rerun; SDK backoff is consistent with the first failure, but its exact prior state was not instrumented and is not retrospectively proven. No database write, security rule or server response was fabricated. No uncancellable write was abandoned using Future.timeout.

## Security results and local boundaries

security-acceptance.* initially failed, exit 1, **64/65**: first fixture reset returned HTTP499 before the owner-read assertion. This recurring local reset failure is preserved; cancellation cause remains unconfirmed. The unchanged suite reran successfully: security-acceptance-rerun.*, exit 0, **65/65**. Rules/assertions were not changed. Protected hashes confirm firestore.rules, the original security suite, native local manifest/Google Services config and main.dart all match the start of this follow-up. No schema or backend changes, migration, paid services or deployment.

## Files changed

- lib/features/auth/data/auth_repository.dart and models/account_action_failure.dart: account-session guards, canonical profile write/sync ordering, password reauthentication/provider validation and fixed safe failures.
- lib/features/profile/widgets/edit_profile_sheet.dart: literal passwords, prevalidation, confirmation, guarded dispatch, correct save ordering, retained errors and partial-success retry; injectable actions for deterministic tests.
- lib/features/auth/pages/forgot_password_page.dart: scrollable recovery, stronger validation/submit guard, fixed safe error and injectable reset action.
- lib/features/profile/pages/profile_page.dart, data/family_member_repository.dart and widgets/add_edit_family_member_sheet.dart: await saves before closing; retain drafts; age validation, narrow heading, loading/Retry and scoped write completion. Removed fabricated fallback name/email while account data loads.
- lib/features/pantry/pages/pantry_page.dart, data/pantry_repository.dart and widgets/add_pantry_item_sheet.dart plus lib/core/widgets/app_shell.dart: all existing add/edit entry points await saves in the sheet; preserve failed drafts, metadata and category; pending guard, validation and loading/Retry. Existing transactional store and permissions retained.
- test/account_recovery_test.dart, test/profile_pantry_recovery_test.dart: **13 new regression cases**. Existing 206 cases remain passing.
- integration_test/stage11_recovery_test.dart and test_driver/stage11_recovery.dart: local-only Android acceptance and retained phase/failure diagnostics.
- audit/stage11/* and documentation: isolated tester/verification instructions, command exits, classifications and full success/failure records. Stage 10 evidence preserved.

## Standalone tester result

build-tester.* exit 0, **80.2 s**, 55.2 MB (57879145 bytes). apk-verification.* exit 0. Package com.example.whatmeal.local, version1.0.0/code1, minSDK24/target36, native project demo-whatmeal-audit matches the guarded local Dart configuration. Existing debug tester certificate reused; native HTTP deny-default/localhost allowlist and FCM/analytics disabled guards verified. No release credential file was present; no signing secret was generated or exposed. Default Firestore8180/Auth9099, no test relay required.

APK SHA-256: **4F49B2DCEC861A2C2697395367AAA8897366C5D9C888A16CF7814E6C15D7B6B2**. Artifact: build/stage11/whatmeal-local-tester.apk. Install and cold start both exited0; COLD TotalTime1592ms. tester-focus.txt confirms isolated package, tester-anr.txt reports no ANR since boot, tester-startup.png was visually inspected and shows original branding/Sign In. This is standalone startup evidence, separate from the debug integration workflow, not full production/release-mode acceptance.

## Prioritized remaining work

1. Email delivery and browser/deep-link reset handling, expired actions, federated/recent-login failure and revocation timing require additional approved configurations/evidence. Only invalid/reused local SDK actions and email/password accounts were verified here.
2. Test permanent SDK listener failures and explicit Pantry/Profile Retry controls, restart while offline, interruption during add/delete, delayed account callbacks and conflicting edits on two devices. Retained-draft failure/retry widgets and actual pantry transactional outage do not establish every recovery path.
3. No approved non-production live-AI project exists; only demo-whatmeal-audit is approved/configured (firebase.audit.json, android/app/src/local/google-services.json, lib/main.dart). Live Gemini/custom providers and native push remain blocked; see prior approval request. No live credentials/calls or trusted sender were introduced.
4. Production signing/attestation, credential-storage decisions, migration and deployment remain separate approvals. No production data was read, modified, migrated or deleted; no rules/backend changes deployed; no paid services/Functions/Blaze enabled. Existing user changes and Stage 10 evidence remain preserved.

The requested core local password/profile/pantry workflows now have actual Android evidence. The entire application is not declared fully certified.

## Final handoff state

All final test/build/verification/install/startup result exit files are zero. git diff --check exited0; existing LF/CRLF notices are informational. APK binary inspection confirms the new fixed account messages are present in Stage 11 and absent from the preserved Stage 10 artifact; this is compiled-code evidence, not additional runtime acceptance. No app source changed after the passing 219-test suite; the later change only added integration recovery diagnostics. Dedicated headless AVD, loopback relay and this continuation's demo backend were intentionally stopped after evidence capture; listener checks found none remaining on 8180/8181/8182/9099/5564/5565. The installed tester remains on the AVD disk. Restart local services/AVD using TESTER.md before manual use.
