# Manual meal-plan save and Calendar correction — October 26, 2026

The phone screenshot reproduced the client validation failure: manual creation made 21 empty accepted slots and Save required every slot to have a name. Manual templates now save a dated parent-only `draft`; untouched slots are not stored as accepted meals. A partially completed template persists named recipes only. An unnamed recipe with actual content still fails validation. Empty AI results remain rejected. The repository requires explicit empty-draft intent, preserves scoped role checks, and records the signed-in actor UID.

The weekly Calendar now displays saved plans with no dishes and offers Edit plan with the original identity/date. It preserves overlapping same-type dishes by full plan path and meal ID instead of hiding all but the newest. Weekly and Home calendars exclude undated/unsaved plans. Home dish navigation keeps the source plan. Planner selections update their route date with `replace`, retaining form state while preventing a cached branch from restoring an old day after editing. Post-save navigation stays inside the actual persisted duration.

Important source files changed:

- `lib/features/meal_plan/models/saved_meal_plan.dart`: transient manual intent and empty-slot filtering; no additional Firestore fields.
- `lib/features/meal_plan/data/saved_plans_repository.dart`: explicit empty-draft saving and authenticated actor metadata.
- `lib/features/meal_plan/data/generated_plan_persistence.dart`: preserve editor intent during draft recovery.
- `lib/features/meal_plan/pages/meal_plan_page.dart`: mark manual creation and synchronize selected route dates; injectable existing repositories for real-page tests.
- `lib/features/meal_plan/pages/generated_meal_plan_page.dart`: save template/partial plans, retain failed drafts, reuse repository injection, and navigate to a covered saved date.
- `lib/features/meal_plan/widgets/meal_calendar_workspace.dart`: complete saved-plan identity, draft visibility, and consistent scheduled-date filtering.
- `lib/features/home/pages/home_page.dart`: consistent saved-date filtering and exact meal routing.
- Tests: `manual_plan_editor_test.dart`, `manual_meal_plan_save_test.dart`, `calendar_selection_test.dart`, and `home_navigation_test.dart`.

Actual final verification:

```text
flutter test test/manual_plan_editor_test.dart test/manual_meal_plan_save_test.dart test/calendar_selection_test.dart test/meal_plan_calendar_test.dart test/generated_plan_persistence_test.dart test/home_navigation_test.dart --reporter expanded
34 passed, exit 0

flutter test --reporter expanded
623 passed, 1 skipped, exit 0

flutter analyze
No issues found, exit 0

flutter pub get --offline --enforce-lockfile
exit 0, isolated source copy

flutter build apk --release --flavor production
exit 0, 245.5 seconds, isolated source/output
```

The skipped test is the opt-in live public-image probe. Widget/repository tests use fake Firestore and mocked platform services; they do not establish live Firebase or phone behavior. The complete suite was rerun after the final draft-visibility fix; its prior 622-pass run and clean analysis remain retained separately. Initial regression/harness failures and the deliberately failing pre-fix draft-visibility test remain in the evidence directory. No interrupted run was counted as passing.

Evidence: `build/manual-save-repair-20261026-582c6495/`, including `focused-final.txt`, `full-tests-final.txt`, `analyze-final.txt`, `build.txt`, and `apk-verification.json`.

Final full-app online APK:

```text
build/phone-release/20261026-manual-save-582c6495/WhatMeal-release.apk
Package: com.example.whatmeal
Firebase project: whatmeal-101
Version: 1.0.0+1
Size: 59,271,505 bytes
SHA-256: 515413BDE83AE3D7FFC8C3C94E430429FCE0946694F88C6A22EB6CC55B5C0392
```

Signature verified and matched the previous online APK's existing tester certificate. This is a release-mode online build, not the Showcase/local flavor; a private distribution keystore remains unconfigured. No phone was connected and the separate emulator backend was unavailable, so this APK was not installed or tested against live Firebase in this repair. Existing production rules/App Check compatibility remains unverified.

No Firebase configuration, security rules, App Check settings, signing keys, dependencies, production data, or existing APKs/backups were changed. The earlier online APK retained SHA-256 `6A7A49A02E4EEF8CB32A1FDAA198C6497DDDE4D935D4099F94926F0300C7766D`. Rule source retained SHA-256 `DB759E4941F8B9C06B097FB7C4FE9F148F7C2ADCBB52DA6AAC9B4ED9E5F7BE77`. No deployment, migration, live AI, or paid service was used. Install the new APK as an update; do not uninstall an existing app to resolve a signature conflict.
