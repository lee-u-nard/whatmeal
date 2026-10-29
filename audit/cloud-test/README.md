# Separate full-app Spark test — current checkpoint

Updated 2026-10-19. **Requested P0 work complete: 71 security cases, 488 Flutter tests, clean analysis, live Android Gemini saving and separate cold reopen passed. The verified normal cloud-test APK is installed and running.** [Final handoff](../final/CLOUD_TEST_HANDOFF.md).

## Isolation and provisioning

- Approved test project: **`whatmeal-gemini-test-20261019`**, project number `952163528165`.
- Separate Android package: **`com.example.whatmeal.cloudtest`**, label **WhatMeal Cloud Test**.
- Firebase Android app: `1:952163528165:android:e184bb528e406cff95530c`.
- Email/password Auth and Standard Firestore `(default)` in `asia-southeast1` were provisioned only in this test project. Firestore reported `freeTier: true`; no billing account was linked, billing was disabled, and AI Logic App Check was ENFORCED at the provisioning check.
- The app uses the exact native test configuration, fails closed on project/app mismatch or missing App Check token, and refuses release/profile builds and emulator-mode defines. Native push initialization is disabled in this test flavor.
- Private configuration: `build/cloud-test/google-services.json` and `android/app/src/cloudtest/google-services.json`. Disposable preverified fixture credentials: `build/cloudtest-private/accounts.json`. These files are ignored; never paste or commit their contents. Fixture sign-in does not verify real email delivery or registration.
- Original account/cache, existing local demo, production configuration, APK and backup-manifest files were not reset or replaced. All **8 protected workspace hashes match** the pre-task baseline (`protected-after.json`). No production deployment, migration, billing upgrade or Cloud Function was performed.

## Executed evidence

| Check | Actual result |
| --- | --- |
| Baseline restrictive rules in fresh isolated Firestore emulator | **65/65 passed, exit 0** (`security-before-optimization.txt`) |
| Cloud/AI/demo isolation unit tests | **21 passed, exit 0** (`guard-tests.txt`) |
| Test-only batch observer codec/forwarding regressions | **6 passed, exit 0** (`capture-tests.txt`); these verify diagnostics, not live Firebase |
| Normal cloud-test bootstrap APK | Build **exit 0, 183.2s**; package/native project/app ID verified; installed and launched |
| Disposable accounts | Imported into this test project only, with administrator preverification; ordinary Android UI sign-in and synthetic profile persistence executed |
| Real Android Gemini runs | First **two workflows failed, exit 1 each**, because saving was rejected; preserved. After the verified rules repair, the next workflow **passed all 8 checkpoints, exit 0, 66s** with selected `gemini-3.8-flash`, one Generate tap and one Save Plan tap |
| Live SDK persistence and account isolation | Exact recipe and dates confirmed with non-cache, non-pending **Source.server** snapshots; ordinary Saved Plans Load/meal details retained identity; outsider UI excluded owner data and the server denied the exact owner plan; owner restored (`android-generation-result.json`) |
| Second run exact native write capture | Privately retained the actual generated recipe and plan batch. Original native bytes/replies were forwarded unchanged; no fabricated SDK response |
| Independent cloud schema probe | Owner-authenticated REST atomic synthetic plan+meal write **HTTP 200**, then only those probe documents removed; not an Android UI acceptance pass |
| Exact rejected batch replay, original rules | **HTTP 403**; zero partial documents; parent-only HTTP 200, child-only HTTP 403. Emulator explicitly reported the **1,000-expression limit** |
| First optional-helper optimization replay | Still **HTTP 403 / expression limit**; diagnostic command exit 0 means it ran, **not that persistence passed** (`replay-helper-attempt` result remains in `replay.txt` until a later run) |
| Regex-only candidate replay | Ran, but still **HTTP 403 / expression limit** (`candidate-replay-regex-only.txt`); not a pass |
| Final equivalent lower-cost validation | **Exact captured recipe replay passed: HTTP 200, both documents present, command exit 0** (`candidate-replay.txt`) |
| Candidate security suite | **71/71 passed, exit 0**, after preserving actual **68/71** and **69/71** failures. Hash-bound receipt accepted by the local evidence guard |
| Draft/recipe/observer regressions | Final **23/23 passed, exit 0** (8 recovery, 9 round-trip, 6 diagnostics). Includes two missing-workspace regressions; previous fixture failure preserved in `failed-draft-recovery-compile/` |
| Complete Flutter suite / analysis | Final **488 passed, exit 0, 99s**; analysis **No issues found, exit 0, 12.1s**. Prior 486-test run and failed analysis preserved before the final workspace guard/lint fixes |
| Verified test-only deployment | **Exit 0**, only `firestore:rules` to `whatmeal-gemini-test-20261019`; active source independently matches exact candidate SHA `49AA394...` (`deployed-rules-check.json`). No Auth/index/Functions deployment |
| Android environment | Existing `whatmeal-stage9-aosp` cold-booted on `emulator-5564`, no wipe or snapshot load/save; old cloud-test binary force-stopped to prevent unintended requests |
| Deliverable fixture-credential verifier | **8 synthetic Node cases passed, exit 0**; stored/deflated UTF-8/UTF-16 detection and invalid archive rejection. These are tooling tests, not Flutter or security acceptance |
| Actual prior APK scans | Normal bootstrap: **scanner exit 0**, no fixture literals in 328 entries. Private integration APK negative control: **scanner exit 1 as required**, all four fixture values detected; wrapper exit 0 confirms expected rejection. Both artifacts predate the final repairs |
| Separate cold reopen | **5 checkpoints, exit 0, 28s**, actual server persistence, exact saved-plan UI identity, outsider denial and owner restoration; **zero Generate taps** (`android-reopen-result.json`) |
| Final normal APK | **Build exit 0, 50s**, `lib/main.dart`, native package/project/app identity and signature verified; **192,173,953 bytes**, SHA **`C9DCD6A42EE9781C555638E8943BE48DFAC5AB4C9A49A2C8E3D839FB74FF063B`**. Four fixture literals absent across 328 entries; update-install/launch exits 0 |
| Actual normal startup | **Passed**: Home and Saved Plans visible; captured process-scoped logs contain zero fatal/unhandled and zero Flutter error lines (`normal-runtime.json`). First inspector scripting failure preserved, not counted as success |

First and second failed Android runs remain under `first-failed/` and `second-failed/`. Private exact payloads/raw logs/current integration APKs remain under ignored `build/cloudtest-private/`. Integration APKs contain disposable fixture credentials and must not be distributed. The only current handoff artifact is **`build/cloud-test/whatmeal-cloud-test.apk`**, with metadata in `apk.json` and actual normal startup in `normal-runtime.json`. The existing original/demo installed APK hashes and all eight protected workspace hashes remain unchanged.

## Root cause and completed repairs

The live recipe was structurally valid and within every recorded field bound. Its ten ingredients and populated metadata exhausted the existing Firestore validator's evaluation budget. This is a rules execution-cost defect, not evidence that owner permissions should be broadened. The failed atomic commit left no orphan plan or meal.

The smallest helper substitution and then the regex-only candidate were insufficient; both failures are retained. Once command approval worked, the first actual 71-case run found **three failures**: fully populated private/household and weekly recipes exceeded the budget, and the optional-field regex changed Unicode length semantics. Restoring exact type/`String.size()` checks fixed Unicode; that intermediate candidate still failed both populated-recipe cases (**69/71**). Those sources, stdout and exits are preserved in `failed-security-68-20261019/` and `failed-security-69-20261019/`; private local coverage and emulator logs remain ignored under `build/cloudtest-private/evidence/`.

The final candidate groups the 17 original nullable type/size checks into two helpers, uses full ten-item ingredient block branches with unchanged partial fallbacks, inlines the existing strict string-list validator, and checks the exact status/accepted pairs. An ingredient still requires exactly the two `name`/`amount` fields with their original string bounds: both required field reads plus exactly two entries enforce that same allowlist. New assertions exercise non-map/type/size/injected fields at positions 0 and 9, with a successful ten-entry control. The common new meal with null replacement links has a fast branch; updates and every linked meal retain the complete original reciprocal and immutable-link validation. All role, ownership, parent-existence and membership conditions remain unchanged. **The exact captured batch and all 71 security cases pass**, including populated ten-ingredient recipes, 21-meal batches and Unicode differential checks. The 71-case matrix is emulator evidence; additional live Android SDK evidence proves the bounded test-project save/reopen and outsider-denial route, not every role/scenario on the cloud.

To protect existing configurations, normal `firestore.rules` remains at its exact pre-optimization hash **`DB759E4941F8B9C06B097FB7C4FE9F148F7C2ADCBB52DA6AAC9B4ED9E5F7BE77`**, and its original 65-case suite remains intact. Only the approved test project's active rules were updated, after all 71 cases and final Flutter checks passed; source readback matches. The isolated config points to `build/cloud-test/verified-candidate.rules`; its previous config/source remain preserved. The separate candidate suite preserves all 65 original cases and adds six recipe-budget, weekly-batch, type/length/injection, link and Unicode/control-character cases. Verified candidate SHA-256: **`49AA394DC5E125072AA73CB1DCF495CAD9185550D19532BA5037FA03AAC5B999`**. Earlier candidate sources and failures remain preserved.

Application repair has **17 passing mock/unit regressions**: a failed initial save retains the genuine generated meals in the existing editor, displays an explicit unsaved notice, and allows Save Plan to retry persistence without regenerating. Draft identity, dates, participant IDs, cuisine and pantry preference are retained; obsolete account/household sessions and missing workspaces are rejected. Generation captures and validates the originating account workspace before using quota. Live successful saving and cold reopening passed; a new forced native save failure is not claimed. Relevant files:

- `lib/features/meal_plan/data/generated_plan_persistence.dart`: session-aware persistence outcome.
- `lib/features/meal_plan/pages/meal_plan_page.dart`: separates generation success from persistence failure.
- `lib/features/meal_plan/models/saved_meal_plan.dart` and `pages/generated_meal_plan_page.dart`: retained unsaved state, source session and existing save action.
- `test/generated_plan_persistence_test.dart`: eight passing failure/retry/stale-session/missing-workspace regressions.
- `test/generated_meal_roundtrip_test.dart`: nine passing regressions for structured ingredient amounts, metadata, editor overrides, ingredient edits, reuse timestamps, and grocery quantities/provenance. Review found that display-string conversion would lose quantities during a save retry; `GeneratedMeal` now preserves the source structure until ingredients actually change.

The Android harness recognizes a genuine retained editor draft before requiring persistence, uses the ordinary Save Plan control, and verifies the exact meal identity in confirmed server snapshots. It separately records initial-save failure and counts Generate/Save taps. Three explicit server reads have 30-second deadlines. The runner archives prior logs/payloads and refuses to display logs if sanitization fails; the final installer compares original/demo APK hashes before/after installation. Both actual Android phases, the final installer and normal runtime inspection executed and passed.

`verify_no_fixture_credentials.cjs` inspects every uncompressed APK entry for exact disposable fixture emails/passwords in three encodings without disclosing them. The final installer refuses installation if this fails. This is a focused fixture-literal check, not a general secret audit; required public Firebase client configuration is retained. Synthetic tests and prior-artifact positive/negative controls passed. `integration-fixture-credentials-detected.json` must report `passed: false`: it correctly rejected the private integration binary. The actual final APK scan **passed**, zero matches across 328 entries, in `fixture-credentials-absence.json`; copied final bytes match that scan's hash.

Executed tooling commands (workspace PowerShell; no network or Android operations):

```powershell
& 'C:/Program Files/nodejs/node.exe' --test audit/cloud-test/verify_no_fixture_credentials.test.cjs
& 'C:/Program Files/nodejs/node.exe' audit/cloud-test/verify_no_fixture_credentials.cjs build/cloud-test/bootstrap.apk audit/cloud-test/bootstrap-fixture-credentials-absence.json
```

The first returned **8 passed, 0 failed, exit 0, 109.9498 ms** in the tool transcript; no original stdout log was saved. The second returned **exit 0**, 328 entries, 241,903,890 uncompressed bytes, zero fixture matches; its `.json`/`.exit` files are retained. The negative control invoked the same scanner against the single ignored integration APK under `build/cloudtest-private/`, returned **scanner exit 1**, and detected all four exact credential values in one entry. Its wrapper required that rejection and exited 0. No credential values were printed. All three runner scripts passed PowerShell parsing, changed-file whitespace checks passed, and all eight protected workspace hashes were independently rechecked unchanged. These checks do not certify the pending candidate or application changes.

During the earlier capacity blocker, the authorized single retry was rejected before execution; no bypass occurred. Safe local work added the hash-bound evidence gate. After approval mode changed, `verify_candidate.ps1` archived prior runs and produced an **actual successful** receipt bound to candidate, suite, replay and security logs. `candidate_evidence.cjs` checked all 71 unique PASS results, the passing summary, no failures and the exact replay. `check_deployed_rules.cjs` then independently compared the active test source to that candidate. The final build/Android scripts required this evidence. The guard's 64 synthetic tests are separate from actual security acceptance.

## Completed sequence and preserved execution history

After the user switched models, normal approval allowed the replay commands to execute. The first actual attempt failed because Firebase refuses a rules file outside its project directory; the runner now copies the candidate into its isolated folder. The regex-only attempt then failed the evaluation budget, and the next optimized attempt passed. **The 71-case security command subsequently failed to start twice because automatic permission review did not finish before its deadline.** On the latest user-authorized continuation, one normal attempt returned **Selected model is at capacity**, again before execution. It was not retried or routed around approval. This is an execution-service blocker, not a Firebase failure or an executed test. Earlier status is retained in `execution-blocker-before-latest.json`; current state is in `execution-blocker.json`.

The user subsequently selected **Ask for approval**, and the normal approved path executed. Actual suite results were 68/71, then 69/71, then 69/71 with local coverage diagnostics, then **71/71 passed** for candidate `49AA394...`. Exact replay also passed for that final candidate, and `candidate-security-receipt.json` binds the successful sources/logs. Earlier approval failures remain history, not the current blocker.

Executed security command (do not repeat unless relevant sources change):

```powershell
./audit/cloud-test/verify_candidate.ps1 -Check security
```

The final replay reports `atomicHttp: 200` and `atomicDocumentsPresent: 2`; rerun it only if the candidate changes. **71/71, 23 focused regressions, 488 full tests and clean analysis have passed.** `deploy_verified_test_rules.ps1` promoted only the exact candidate using explicit `--project whatmeal-gemini-test-20261019` and the isolated `build/cloud-test/firebase.json`. `check_deployed_rules.cjs` confirmed the active test source matches. Normal/demo rules remain unchanged. The 64 synthetic evidence-gate tests also pass for the final candidate; these are tooling checks, separate from the actual 71-case emulator suite.

After those checks, `run_android.ps1 -Phase generate` passed for a bounded one-person, one-day Dinner request: real editor/listener success, explicit naming, confirmed server reads of exact plan/meal/dates, UI reopening, outsider denial and owner restoration. The ignored `defines-reopen.json` was created from actual passing IDs. `run_android.ps1 -Phase reopen` then passed its separate cold restart with zero Generate taps. Do not repeat generation just to recreate evidence; the actual saved plan remains available.

Finally, `build_and_install.ps1` built the normal app with **no fixture credential defines**, verified package/native identity/signature and credential absence, recorded size/SHA-256, update-installed only `.cloudtest`, and launched it without clearing data. Final path: **`build/cloud-test/whatmeal-cloud-test.apk`**. `verify_normal_startup.ps1` captured actual Home/Saved Plans controls and clean scoped logs; the first inspector's read-only-variable scripting error is preserved in `failed-normal-startup-inspector/`, and the corrected inspection passed. See the final handoff for install/run commands.

Live verification here is limited to the requested `gemini-3.8-flash` route. Prior AI-only smoke evidence remains in `audit/firebase-test/README.md`. No other model, native push, simultaneous-device synchronization or production readiness is claimed.
