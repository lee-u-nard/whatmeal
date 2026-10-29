# Android/Java diagnosis — 2026-10-05

No firewall/security settings or project Java/Gradle configuration were changed.
No release build was retried because a safe working remedy has not been established.

Observed configuration: Gradle wrapper 9.3.1; configured daemon enabled, parallel
builds disabled, max workers 2; JVM heap 1536 MB, metaspace 512 MB, code cache
256 MB. Installed Java 17.0.12 and Android Studio bundled Java 21.0.10 were tested.
`--no-daemon` still uses a single-use daemon when JVM settings require it.

| Check | Actual result |
|---|---|
| Java 17 standalone NIO pipe | Failed loopback initialization |
| Java 21 standalone NIO pipe | Passed |
| Java 21 NIO Selector.open | Failed: Unable to establish loopback connection |
| Explicit TCP bind/connect 127.0.0.1 and ::1 | Both passed with both JDK probes |
| Gradle help/stacktrace using Java 17 | Failed before app compilation |
| Gradle help/stacktrace, process-local JAVA_HOME=Java 21 | Same failure |
| Firestore emulator v1.22.0 with Java 21 | Failed opening Netty NIO selector before tests |
| Firewall profiles | Enabled; policy defaults reported NotConfigured |
| Security products inventory | Defender and McAfee reported; causation NOT established |

Both Gradle and the emulator fail through Java WEPollSelector/PipeImpl and
UnixDomainSockets.connect with `Invalid argument: connect`. Ordinary IPv4/IPv6
loopback works. This is evidence against an app-code or generic TCP-loopback
failure, not proof that security software is uninvolved.

A public [matching upstream report](https://github.com/openai/codex/issues/40902)
describes Selector.open failing for Java launched from Codex on Windows while a
normal host PowerShell succeeds. Our stack matches, so a command-runner/environment
interaction is a plausible explanation. We have not run the outside-Codex control
on this machine and cannot claim that it is confirmed or fixed here.

Next safe control: run the included `LoopbackProbe.java` using the Android Studio
JDK in a normal user PowerShell. If Selector.open works there, run Gradle `help`
there, then a release APK build using the same known SDK/JDK. If it fails there as
well, investigate host Java/Unix-domain-socket policy with the administrator using
the minimal reproducer. Do not disable security products, add broad firewall
exclusions, alter adapter bindings or bypass the managed execution environment.

Evidence: `gradle-diagnostic.txt`, `gradle-jdk21.txt`, `LoopbackProbe.java`,
`emulator-security.txt`, `firestore-emulator-startup.txt`. The emulator was started
with project `demo-whatmeal-audit`, only Firestore, listening on 127.0.0.1:8180.
It exited before the security probe could execute. No rules were deployed.

Local retry on a working host, from the repository root:

```powershell
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
& "$env:JAVA_HOME/bin/java.exe" audit/stage2/LoopbackProbe.java
firebase emulators:exec --only firestore --project demo-whatmeal-audit --config firebase.audit.json 'node audit/stage2/emulator_security_probe.mjs'
```

The security probe is intentionally expected to report C01/C02 failures under
the unchanged rules. A successfully running emulator is not a secure-rule result.
