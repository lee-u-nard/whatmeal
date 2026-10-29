# Stage 15 manual-session follow-up, 2026-10-17

All commands ran from the repository root. Auth 9099 / Firestore 8180 remained running with demo-whatmeal-audit; no database reset or app-data clear. No live provider requests or security-suite rerun.

## Flutter (serialized)

Tool: C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat.

- `flutter test test/app_shell_accessibility_test.dart`: first attempt exited 1 at compilation (duplicate underscore parameters under the project's Dart language version); this initial output was displayed in the tool transcript, not captured to a file.
- Same command after correcting parameter names: exit 1; `header-tests-first-runtime-failure.txt` and `.exit` preserve bottom-row overflow and an incorrect test assumption that Flutter tooltip semantics use a label. The inspected semantics instead report the tooltip field; final assertions check that field directly.
- Same command with diagnostic dump: compile exit 1 (`header-tests-second.*`, missing rendering diagnostic import), then exit 1 (`header-tests-third.*`, test SemanticsHandle disposed too late). Harness corrected; no application authorization or error assertions removed.
- `flutter test`: intermediate 252 passed, exit 0 (`flutter-tests.*`), before adding the system-inset case/fix.
- `flutter test test/app_shell_accessibility_test.dart --plain-name 'bottom tabs stay above Android system navigation'`: exit 1 (`system-inset-reproduced.*`). Expected bottom <=592; Home text bottom was 630.5 on a 640px view with a 48px system inset.
- Dedicated AVD name confirmed as whatmeal-stage9-aosp, then `adb -s emulator-5564 emu kill` exited 0. Backend was not stopped.
- `flutter test`: final 253 passed, exit 0, 70 seconds (`flutter-tests-final.*`). Two new widget cases exercise injected fake repositories, actual GoRouter navigation, unread semantics, all five narrow headers and the Android system inset. Not live Firebase or native screen-reader proof.
- `flutter analyze`: clean, exit 0, 58.5 seconds (`analyze.*`). Initially silent, eventually completed; no second Flutter process was started while it ran.
- `./audit/stage15/manual-followup/build_tester.ps1`: exact build/configuration in script. Previous Stage15 artifact and evidence are retained. Process-only Java/Gradle settings reuse the prior verified workaround; no system or project security configuration changed.

## Android observation before repair

ADB: C:/Android/Sdk/platform-tools/adb.exe; device emulator-5564 only.

- `shell uiautomator dump /sdcard/whatmeal-current.xml`, `pull`, XML inspection: local package focused; notification/profile header controls unlabeled. Initial calendar navigation succeeded from Oct12–18 to Oct19–25 (`calendar-before.xml`, `calendar-next.xml`).
- `shell input tap 275 608`: Android system recent-apps intercepted the supposed Profile tap. `profile-before.png` confirms recent-apps, not successful app navigation; `profile.xml` is the stale app hierarchy and is not a passing Profile checkpoint.
- `shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity`: exit 0; retained session, no restart/data clear. `app-restored-before.png` captures the transition and is not a settled-screen result; `app-restored-settled.png` confirms bottom tabs overlap the Android system navigation bar.
- All UI artifacts are local demo evidence. No account passwords, Auth tokens, invitation tokens or email-action links are included.
