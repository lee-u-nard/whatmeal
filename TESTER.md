Separate local demo is ready: **WhatMeal Demo** has its own package, backend and two disposable accounts. [Open/demo guide, private account-file location and verified APK](audit/stage15/showcase/README.md). Original account/cache/backup preserved; no production changes; live AI pending. The separate demo passed 31 actual Android UI checkpoints, 297 Flutter tests, analysis and a backend save/import/cold-start check.

**Latest final handoff — 2026-10-19:** [Current demo APK, 447 tests, actual Android verification and limits](audit/final/REPORT.md). Final artifact: build/final/whatmeal-demo.apk; SHA-256: 56DDB70183DB9E8D4C6F3A345FAEFCA7A193A7B10AD72BA90E3E142279F693E9. The earlier results below are historical; the separate demo remains local-only with live AI pending.

Latest bounded Stage 15 handoff (2026-10-18): [exact APK, install/run commands and readiness](audit/stage15/demo-handoff/HANDOFF.md). Shared two-account Android recovery passed 10 checkpoints; final 294 tests and analysis passed. Rebuilt tester installed to cached Home; original account/backup preserved. Complete original-account connected demo remains blocked by unrecovered original backend data. No production or live AI.

## Latest food recovery tester — 2026-10-18

The [food recovery evidence](audit/stage15/food-recovery/REPORT.md) records 294 passing Flutter tests, clean analysis, and all 10 Android recovery checkpoints passing with a disposable local account. Current artifact: `build/stage15/food-recovery/whatmeal-local-tester.apk`; SHA-256 `D80D00FB8A7D2652B6B2558A84D5CD4059A220B90C7709125C1B8A349F3FB06B`. It was verified, update-installed without clearing data, and cold-started to cached Home without a visible ANR.

The original cached account and private device backup are preserved. Original Auth9099/Firestore8180 remain stopped: no original paired server export was found, and no empty backend/account recreation was performed. Disposable services were exported privately and stopped. Local demo only; live AI remains pending an approved test project. No production changes or deployment.

# Isolated WhatMeal tester

Use the [Stage 15 final tester guide](audit/stage15/TESTER.md) and matching APK. It uses demo-whatmeal-audit and local Auth/Firestore only. This is not a production release; do not use the superseded Stage 7 APK.

No non-production live-AI project is approved. The [configuration request](audit/stage10/LIVE_AI_APPROVAL.md) remains pending. Never paste credentials into reports or chat.
# Updated installed tester

The Stage15 [form-repair follow-up](audit/stage15/forms-followup/REPORT.md) extends the navigation repairs to editors and household sheets. Latest artifact: `build/stage15/forms-followup/whatmeal-local-tester.apk`; earlier artifacts remain preserved. See the linked report for exact hash, verification, build/install scripts and retained manual-session state. Local demo only; live AI remains pending, no production changes.


## Latest household recovery checkpoint — 2026-10-18

Use the rebuilt [household recovery tester and evidence](audit/stage15/household-recovery/REPORT.md), artifact `build/stage15/household-recovery/whatmeal-local-tester.apk`, SHA-256 `7A0FE24C248747ED29C0ECDA7FA4A8AB5DB8ECECD1B34F3EFC024530B2BB24C8`. It is installed on the connected isolated AVD and cached Home was observed.

**Do not blindly restart the primary backend:** its former in-memory9099/8180 process stopped unexpectedly and no workspace export was found. The AVD's private stopped-state backup was verified, and cached Auth identity retained; server dataset recovery remains unverified. No account recreation was performed. Only disposable tests used independent9199/9180, with a separate ignored fixture export; those services are now stopped. Preserve the original device/data while resolving the backend recovery decision. Live AI remains pending, and production was untouched.

## Latest departure recovery tester — 2026-10-18

The [departure recovery evidence](audit/stage15/departure-recovery/REPORT.md) records284 passing Flutter tests, clean analysis, and10 passing Android checkpoints with disposable accounts. Latest local-only artifact: build/stage15/departure-recovery/whatmeal-local-tester.apk. SHA-256: 71E01843ED8700461F1A81BFE0C23E8E222C4483DEADCBD7D55DE9DB6CC147C7. Original branding and existing tester signer retained; this is not a production release.

No original paired Auth/Firestore export was found in the project/temp/Firebase-cache search. The available exports are disposable fixtures, with no normal-account record. Original9099/8180 remain stopped, no normal account was recreated, and the private device backup remains protected. Live AI remains pending. Do not run the historical empty primary-backend start command as a recovery action.
