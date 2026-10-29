# Stage15 local form repairs

2026-10-17. Continues the [navigation follow-up](../manual-followup/REPORT.md). Account and demo data retained; backend never stopped/reset. No production reads, changes or deployment. No live AI requests, new credentials, paid services or Cloud Functions.

## Bugs repaired

- **Form submit controls overlapped Android system navigation.** Actual pantry editor bounds were y572–620 on a640px screen with system navigation beginning y592. The same missing bottom-padding pattern occurred in pantry, grocery, profile, dietary-profile and create/join sheets. Added system padding alongside keyboard insets. Flutter computes system padding as the unobstructed remainder, so it does not double-count the keyboard. After installing the update, pantry's entire button is y524–572; native blank submission shows required-field errors and retains the editor.
- **Household sheets could overflow with the keyboard/enlarged text.** Create/join used fixed Columns without a scroll viewport. Both corrected reproduction cases overflowed horizontally; keyboard cases also overflowed vertically. They now scroll and their headings take available width beside Close. Existing session/authorization/late-navigation guards are untouched.
- **Enlarged-text horizontal overflow.** Pantry's category dropdown did not constrain its selected text; profile's heading competed with Close in a fixed Row. The new regressions reproduced both. Made the dropdown expanded and bounded the heading without changing its style. Household Close controls also now have tooltips.

No schema, persistence, Auth mutation or permission logic was changed. Original branding/colors and all prior fixes remain intact.

## Modified source and tests

- `lib/features/pantry/widgets/add_pantry_item_sheet.dart`: bottom system padding and bounded category dropdown.
- `lib/features/grocery/widgets/grocery_item_editor.dart`: bottom system padding.
- `lib/features/profile/widgets/edit_profile_sheet.dart`: bottom system padding and bounded heading.
- `lib/features/profile/widgets/add_edit_family_member_sheet.dart`: bottom system padding.
- `lib/features/family/pages/family_space_page.dart`: create/join scrolling, bottom system padding, bounded headings and Close labels.
- `test/form_system_insets_test.dart`: **12 new widget regressions** covering all six forms at320x640,1.6textscale,48px system navigation and keyboard0/240px. Whole submit button must remain above the obstruction and hit-testable, without framework errors. Household cases require the real sheet to open, then simulate keyboard arrival.

Existing staged/uncommitted work was preserved. Git diffs against older staged versions include earlier stages; those earlier changes were not recreated or undone. Build/verification/open scripts are isolated in this evidence directory and preserve previous APKs.

## Actual executed checks

| Check | Result | Evidence |
|---|---|---|
| First reproduction | exit1, initial reported4pass/8fail; household harness counts are invalid evidence | reproduced.txt/.exit; COMMANDS.md explains opener/matching bug |
| Corrected household reproduction | **0pass/4fail, exit1** before repair | household-reproduced.txt/.exit |
| Focused form/account/household/recovery suite | **37passed, exit0,21s** | focused.txt/.exit |
| Final full Flutter suite | **265passed, exit0,102s** | flutter-tests.txt/.exit |
| Final Flutter analysis | **No issues, exit0,50.4s** | analyze.txt/.exit |
| Local release-mode tester build | **Succeeded, exit0,45.4s** | build-tester.txt/.exit |
| APK identity/demo/native-network policy/signature | **Passed** | apk-* verification files/exit codes |
| Install with `-r`, no data clear | **Success, exit0** | install.txt/.exit |
| Android launch | **COLD, exit0,1126ms** | launch.txt/.exit |
| Protected files | **All five unchanged** | protected-final.json |
| Android ANR | **None since boot** | lastanr.txt |

Flutter tests use isolated fakes/mocks/widgets; they are not evidence of live providers, real network failures or concurrent devices. The65 security acceptance cases were not rerun because that fixture resets the backend and the user requested preserving their account/data. Their previous passing evidence remains historical; rules and suite hashes are unchanged.

## Native Android observations after repair

Standalone local tester, AOSP AVD, real native input via ADB; not Flutter simulated typing. No app-data clear, account switching, password changes or valid save submissions were performed.

- Pantry: button fully above system navigation; blank native submission shows two Required errors and leaves the editor open. Injected `UnsavedLocalDraft` into the focused native text field, observed the real AOSP keyboard, scrolled to the full button at y278–326 above the keyboard beginning y346. Dismissed keyboard and closed the draft; pantry remained empty. See pantry-editor-after.xml, pantry-validation.xml, updated-native-draft.xml, pantry-keyboard-scrolled.xml, pantry-keyboard-after.png and pantry-cancelled.xml.
- Grocery: full submit control above navigation; blank native submission shows `Enter an item name.`. Closed it; list remained empty. See grocery-editor-after.xml, grocery-validation.xml, grocery-cancelled.xml.
- Account profile: retained the intended demo account; editor scrolled to the full Save Changes control at y454–504. No name/email/password edits or save were submitted. Back returned to the unchanged profile. See profile-account.xml, profile-editor-scrolled.xml, profile-cancelled.xml and final-profile.xml.
- Household create: full button y524–572 with keyboard hidden and y278–326 above the real keyboard. No Create was submitted; Close returned to No Shared Family Space. See household-create.xml, household-create-focus.xml, household-keyboard-after.png, household-create-cancelled.xml.
- Household join: token remained empty; full button y524–572 normally, y318–366 above the real keyboard beginning y386 (no suggestion row for this field). No Join was submitted; Close returned to No Shared Family Space. See household-join.xml, household-join-keyboard-settled.xml, join-keyboard-after.png, household-cancelled.xml. Earlier focus-frame XML is retained separately; the settled screenshot establishes the actual IME boundary.
- Returned to Home, screenshot visually inspected, account still retained, no ANR. See final-home.xml/.png and lastanr.txt. App and backend left running for manual testing.

Dietary editor placement and enlarged text/keyboard combinations have new widget coverage; they were not all exercised natively in this session. Native save-success/network-failure/member operations retain their earlier bounded Stage15 evidence; this follow-up does not repeat or expand those claims. No arbitrary Android settings/security controls or unrelated applications were changed. The AVD emitted its prior Windows toolbar warning, then booted in22575ms and completed these checks.

## Latest APK

- `build/stage15/forms-followup/whatmeal-local-tester.apk`, **57,895,529 bytes**.
- SHA-256: **0BCDECD18A853F80DC2289C59FBB4D77EFB505D555F47EB0B63C893A3AB7F325**.
- Package **com.example.whatmeal.local**; native project **demo-whatmeal-audit**; existing Android Debug v2 tester signer verified. Not a production release.
- Earlier `build/stage15/whatmeal-local-tester.apk` and `build/stage15/manual-followup/whatmeal-local-tester.apk` are preserved.
- Exact commands/reproductions: [COMMANDS.md](COMMANDS.md); [build](build_tester.ps1), [verification](verify_tester.ps1), [AVD/update/launch](open_tester.ps1). Flutter commands ran serially; AVD stopped during final tests/build, then reopened with retained app data. Backend stayed running throughout.

## Remaining work and boundaries

Live AI remains pending an explicitly approved non-production live project. Only **demo-whatmeal-audit** is approved/configured (`firebase.audit.json`, `android/app/src/local/google-services.json`, guarded Dart startup). No live API key was used or printed. Native push/trusted sender, simultaneous devices, physical-device/release attestation, secure-storage migration and production signing/migration/deployment remain unverified/separate decisions. No approval for those changes is inferred.

Continue with native household create/join failure/draft recovery on disposable accounts, role-specific UI coverage, and broader native accessibility/date-picker/keyboard cases. Current user's account and stored records must remain intact; do not run reset-based acceptance fixtures against this manual backend. This batch closes form-layout defects; it does not certify the entire application complete.
