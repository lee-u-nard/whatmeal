# WhatMeal — isolated Spark test handoff

Completed October 19, 2026. **Ready for the verified isolated Gemini demonstration on `emulator-5564`.** WhatMeal Cloud Test is running with the disposable plan-owner account and its real saved Gemini plan. This is a debug test build, not a production release.

## Final APK

- Path: `C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/build/cloud-test/whatmeal-cloud-test.apk`
- Package: `com.example.whatmeal.cloudtest`; project: `whatmeal-gemini-test-20261019`.
- Size: **192,173,953 bytes**; normal entrypoint `lib/main.dart`.
- SHA-256: **`C9DCD6A42EE9781C555638E8943BE48DFAC5AB4C9A49A2C8E3D839FB74FF063B`**.
- Signature, native project/app identity and debug-only configuration verified. All 328 uncompressed APK entries were scanned; none contained the four disposable fixture email/password literals. This is a focused fixture check, not a claim that public Firebase client configuration is absent.

Already installed and cold-launched. To update-install and open it again without clearing data:

```powershell
$adb = 'C:/Android/Sdk/platform-tools/adb.exe'
$apk = 'C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/build/cloud-test/whatmeal-cloud-test.apk'
& $adb -s emulator-5564 install -r $apk
& $adb -s emulator-5564 shell am start -W -n com.example.whatmeal.cloudtest/com.example.whatmeal.MainActivity
```

Use only the existing disposable test-project accounts in the ignored local file `C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/build/cloudtest-private/accounts.json`. Those fixture email/password literals are absent from the deliverable and are not printed here. No additional setup is required on this registered AVD. Another device needs its own approved test-project App Check debug registration; keep enforcement enabled and do not paste tokens into chat.

## Actual verification

| Check | Result and scope |
| --- | --- |
| Exact originally rejected recipe replay | HTTP 200; both atomic documents present; exit 0. Local isolated emulator only |
| Candidate security acceptance | **71/71, exit 0**: original 65 cases retained, recipe/weekly budget, Unicode, schema/type/bounds/injection, ownership/roles/invitations/isolation/replacement coverage |
| Focused Flutter regressions | **23 passed, exit 0**: 8 persistence/session/workspace, 9 ingredient round-trip, 6 diagnostic forwarding. These overlap the full suite |
| Final complete Flutter suite | **488 passed, exit 0, 99 seconds** |
| Final analysis | **No issues found, exit 0, 12.1 seconds** |
| Local tooling tests | 64 synthetic evidence-gate tests passed; 8 synthetic credential-scanner tests passed. These are not security-suite or live-provider passes |
| Test-only rules deployment | Exit 0; only `firestore:rules` to the explicit approved project. Active source matches exact candidate SHA `49AA394DC5E125072AA73CB1DCF495CAD9185550D19532BA5037FA03AAC5B999` |
| Live Android Gemini workflow | **8 checkpoints, exit 0, 66 seconds**, selected `gemini-3.8-flash`, one Generate tap and one Save Plan tap. Real Firebase AI Logic SDK, normal app controls, one synthetic adult/day/Dinner/Filipino fixture |
| Persistence and account isolation | Confirmed `Source.server` plan and meal snapshots with no cached/pending-write success; exact IDs/dates/recipe, normal Saved Plans Load and details, outsider UI exclusion plus real server denial, owner restoration |
| Separate cold reopen | **5 checkpoints, exit 0, 28 seconds**, server-confirmed same plan and meal, repeated outsider denial and owner restoration; **zero Generate taps** |
| Final normal APK | Build exit 0, 50 seconds; install and launch exits 0. Actual Home visible with one saved plan; scoped startup logs contained zero fatal/unhandled exceptions and zero Flutter error lines |

Each Android phase is **one functional workflow**. The framework's additional teardown pass is not counted as another acceptance test. Accounts were preverified fixtures; this does not verify real registration or email delivery. One AVD was used sequentially, not two simultaneous devices.

## Fixes delivered

- Reduced rules evaluation cost without changing accepted field sets, roles, ownership or reciprocal replacement requirements. Restored exact Unicode string-size behavior after the first candidate's regression was detected.
- Retained genuine generated drafts after a save failure; Save Plan retries persistence rather than requesting AI again. Stale account/household sessions and missing workspaces fail closed.
- Preserved structured ingredient amounts and recipe metadata through editor/save retries; actual ingredient edits invalidate the old source detail, and reused meals receive fresh identity/time.
- Validated and captured the originating account workspace before generation can consume quota.
- Added exact-source verification gates, private/redacted diagnostic handling, bounded server reads, prior-attempt archives and mandatory fixture-credential exclusion before final APK naming/installation.

Save-failure recovery passed mock regressions. The final live run's initial save succeeded; a new forced native save-failure scenario is **not** claimed.

## Preservation and limitations

All eight protected workspace hashes match the baseline, including normal/demo Firebase configuration, original root rules, the existing demo APK and the private AVD backup manifest. Original and showcase installed APK hashes also match before/after installation. No original-account sign-out, data clear, backend replacement, migration, backup overwrite, GitHub operation, production access/deployment, paid service, Cloud Function or App Check weakening was performed.

Only **Firebase AI Logic / Gemini `gemini-3.8-flash`: PASS — LIVE VERIFIED** for this bounded approved-project route. Other models/custom provider routes remain not live-verified here. Native push delivery, physical/simultaneous multiple devices and production readiness remain unverified. The previously missing original local backend export was not recovered or replaced. Production migration/deployment and release signing require a separate future decision.

The existing local demo and original account environment remain separate. The cloud test fixtures were not imported into either.

## Evidence and reproduction

[Detailed results, source files and commands](<C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/audit/cloud-test/README.md>), [APK metadata](<C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/audit/cloud-test/apk.json>), [live result](<C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/audit/cloud-test/android-generation-result.json>), [cold result](<C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/audit/cloud-test/android-reopen-result.json>), [normal startup](<C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/audit/cloud-test/normal-runtime.json>).

Actual guarded commands used: `verify_candidate.ps1 -Check replay`, `verify_candidate.ps1 -Check security`, `verify_flutter.ps1`, `deploy_verified_test_rules.ps1`, `start_avd.ps1`, `run_android.ps1 -Phase generate`, `run_android.ps1 -Phase reopen`, `build_and_install.ps1`, `verify_normal_startup.ps1`, all in `C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/audit/cloud-test/`. No rerun is needed for handoff; generation must not be repeated just to recreate evidence.

Earlier 68/71 and 69/71 rule failures, two failed live saves, nullable fixture/app compilation failures, analysis output and the first startup-inspector scripting failure are preserved. The original failed disposable recipe has a stable byte-identical private replay fixture; later success did not replace it.

![Final normal WhatMeal Cloud Test Home](<C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal/audit/final/cloud-test-normal-home-C9DCD6A4.png>)
