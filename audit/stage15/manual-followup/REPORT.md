# Stage 15 manual-session follow-up

2026-10-17. Local demo backend and the existing dedicated Android AVD only. Existing work, original Stage15 APK, security suite, rules, native safeguards and user's demo data retained. This is a targeted continuation, not a replacement audit.

## Reproduced and repaired

1. **Android bottom-tab interception:** the shell's fixed-height bottom bar ignored the 48px Android system navigation inset. Native input at the apparent Profile location opened Android recent apps, rather than Profile. `profile-before.png` and `app-restored-settled.png` preserve the observations. The widget regression failed with text bottom630.5 versus allowed592 on a 640px display. Wrapped the bottom bar in SafeArea, preserving its original styling and 64px app-control height. Installed-APK semantics now place every tab within y529–592, above Android's navigation area. Native taps on all five tabs succeeded after repair.
2. **Unnamed header actions:** actual Android accessibility XML showed empty content descriptions for notification and avatar controls. Added notification tooltip with live unread count, an explicit family-profile button label and pantry-add tooltip. The visual unread badge is excluded from semantics to avoid announcing its numeral twice. Actual installed-APK XML now names the controls, and native notification/profile shortcut taps succeeded. This does not establish full TalkBack acceptance.
3. **Narrow layout:** new 320px widget coverage exposed a bottom-row overflow using the test font. Nav items now share available width; the app-bar title uses bounded text/ellipsis so long titles retain the header controls. No logo, colors or feature changes. No claim that the test-font overflow itself was a production-font crash.

`lib/core/widgets/app_shell.dart` contains the changes. Optional repository/service arguments enable isolated widget coverage; default production wiring is unchanged. Prior pantry scope/error handling and badge key are preserved. `test/app_shell_accessibility_test.dart` adds two regression cases.

## Actual verification

| Kind | Result | Evidence |
|---|---|---|
| Final full Flutter suite | **253 passed, exit0,70s** | flutter-tests-final.txt / .exit |
| Flutter analysis | **No issues, exit0,58.5s** | analyze.txt / .exit |
| System-inset case before fix | **Failed, exit1** | system-inset-reproduced.txt / .exit |
| Local release-mode build | **Succeeded, exit0,108.9s** | build-tester.txt / .exit |
| Package/native project/network/signature | **Passed** | apk-identity/project/native-guards/network-security/signature files and exit files |
| APK install/update | **Success, exit0, no data clear** | install.txt / .exit |
| Android app startup | **COLD, exit0,2086ms** | launch.txt / .exit |
| Native input/navigation | **Observed passing eight checks:** Home, Profile tab, Pantry, Grocery, Meal Plan, notification inbox, Android Back, header-profile shortcut | updated-*.xml; final-home.xml; screenshots |
| Login retention | **Actual local app profile shows the intended demo account after AVD restart/APK update** | updated-profile.xml; updated-header-profile.xml |
| ANR check | **None since boot** | lastanr.txt |
| Protected files | **All five unchanged** | protected-final.json |

These widget tests use fake repositories and GoRouter. Android checks used the standalone release-mode tester with real native input and the local Firebase SDK/backend. They are navigation/empty-state smoke checks; prior32-checkpoint core/household acceptance was not rerun and is not replaced. No new live AI, push, multi-device, household mutation or failure-recovery acceptance is claimed.

Failed harness attempts are preserved/explained in [COMMANDS.md](COMMANDS.md). The intermediate252-test pass occurred before the system-inset fix; final253-test pass is authoritative. No failures were dismissed, permission checks bypassed or backend reset performed. The AVD emitted its previously seen Windows extended-toolbar warning, then booted in37825ms and completed the observed runtime checks; it is not evidence of an app failure or a proven systemic root cause.

## Updated tester and ongoing manual session

- APK: `build/stage15/manual-followup/whatmeal-local-tester.apk`, **57,895,529 bytes**.
- SHA-256: **0CAA58445C41A537F3899554C7DD6108D8B599B260E23D849AC2C88F14ED8748**.
- `com.example.whatmeal.local`; native project **demo-whatmeal-audit**; existing Android Debug v2 signer verified. This is not production signing.
- Original `build/stage15/whatmeal-local-tester.apk` remains intact; do not overwrite earlier evidence or assume its hash applies to this follow-up.
- Backend remains at127.0.0.1 Auth9099 / Firestore8180; AVD whatmeal-stage9-aosp / emulator-5564. Backend was not stopped/reset. AVD was stopped during build, reopened with its existing data, APK installed with `-r`, then left running on Home.
- [Build script](build_tester.ps1), [APK verification](verify_tester.ps1), [open/install script](open_tester.ps1). Run serialized from repository root; scripts preserve prior artifacts and use process-only build settings.

## Remaining limits / next work

Live AI is still pending: no approved non-production live project has been confirmed. The only approved project is **demo-whatmeal-audit**, configured by `firebase.audit.json` and `android/app/src/local/google-services.json`, with Dart/native guards unchanged. No live credentials were used. Native push/trusted sender, simultaneous devices, secure credential-storage migration and production signing/migration/deployment remain separate work requiring the previously documented configuration/approvals.

Next feasible acceptance work: native keyboard/large-text/form handling on the repaired viewport, role-specific UI and simultaneous isolated devices where resources permit. These are not certified complete by the smoke tests. No production project/data was read, changed or deployed. No paid service or Cloud Function was introduced.
