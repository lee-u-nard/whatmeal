# Local form continuation, 2026-10-17

Repository-root commands; Flutter commands serialized. Tools are the same installed Flutter3.44.5/Dart3.12.2, Android platform tools and Android Studio jbr used for Stage15. Backend remains demo-whatmeal-audit / Auth9099 / Firestore8180, without resetting emulator data. Original Stage15 and manual-followup artifacts are preserved.

## Reproduction

`adb -s emulator-5564 shell uiautomator dump /sdcard/whatmeal-current.xml`, `adb pull`, XML inspection and screenshots were used to observe each screen before coordinate input. No cloud CLI or production data access.

- Opened Pantry tab and Add pantry item. `pantry-editor-before.xml` shows Add to Pantry bounds `[20,572][300,620]`, overlapping system navigation starting y592 on the 640px display; screenshot retained.
- Focused Ingredient Name, confirmed native editable focus, typed `UnsavedLocalDraft` via `adb shell input text`, then observed native AOSP keyboard and field content (`pantry-native-draft.xml`, `pantry-native-keyboard.png`). This is injected native Android input, not physical typing or Flutter's simulated enterText.
- Tapped the observed Close control; `draft-discarded.xml` confirms Your Pantry is Empty. No save was submitted, account/password/profile/household contents were not changed.
- `flutter test test/form_system_insets_test.dart` -> `reproduced.*`, exit1, initial reported4pass/8fail. This initial harness did not scroll to household openers and could match the underlying page button; its household counts are invalid acceptance evidence. It also exposed pantry dropdown/profile heading horizontal overflow and grocery/dietary system-inset failure.
- Corrected household harness to ensureVisible the opener, require a BottomSheet and apply keyboard inset after opening. `flutter test test/form_system_insets_test.dart --plain-name household` -> `household-reproduced.*`, exit1,0pass/4fail. Actual create/join sheets overflowed horizontally; keyboard variants also overflowed vertically. No assertion was weakened.

## Fix verification

`flutter test test/form_system_insets_test.dart test/profile_pantry_recovery_test.dart test/grocery_editor_test.dart test/account_recovery_test.dart test/household_final_recovery_test.dart` -> `focused.*`, exit0,37passed,21s. Includes12new form cases at320x640,1.6textscale,48px system navigation and keyboard0/240px. Assertions require the whole submit button above the obstruction and hit-testable, with no framework error. Existing account/household continuation and failure-retry assertions remain intact.

Confirmed dedicated AVD name before `adb -s emulator-5564 emu kill` (exit0); stopped only the AVD for final checks/build. The backend remains running and device app data is not cleared.

Final commands and results are recorded by `flutter-tests.*`, `analyze.*`, `build-tester.*`, the local APK verification files, and install/launch files. Exact build/configuration lives in [build_tester.ps1](build_tester.ps1), package/signature/network checks in [verify_tester.ps1](verify_tester.ps1), and AVD reopen/update/launch in [open_tester.ps1](open_tester.ps1). No `--no-pub`, concurrent Flutter builds/tests, system security changes, rules changes or live provider calls.
