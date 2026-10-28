# WhatMeal local compatibility backport

Base: published cloud_firestore_platform_interface6.6.12, copied from the installed Pub cache. All52 lib files are initially byte-identical; BSD LICENSE retained. Native Firebase SDKs, Pigeon protocol, dependencies and package version remain unchanged.

Reason: the actual Android offline meal test reproduced an unhandled duplicate transaction-completer failure. Upstream issue https://github.com/firebase/flutterfire/issues/18551 and merged fix https://github.com/firebase/flutterfire/pull/18554 identify the await/native-event race. This package's older bridge also lacks an early completion guard.

The only library edits are in lib/src/method_channel/method_channel_firestore.dart: stop processing terminal events after completion and re-check completion after awaiting failure storage. The original transaction error remains delivered; no rule/auth/error suppression, retries, server writes or result fabrication is added.

Root regression test test/firestore_transaction_race_test.dart deterministically interleaves a native error with a Dart-handler failure. Actual Android recovery and the full app suite must also pass. A root path override makes this local/reviewable; the global Pub cache was not edited.

Maintenance: remove the override/copy only when a compatible, separately verified Firebase upgrade includes the guards and regression/native checks pass. Do not drop this patch just to resolve dependencies. See audit/stage15/food-recovery/REPORT.md for real results and remaining limitations.
