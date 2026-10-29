# WhatMeal demonstration preparation

For October 29, 2026. This is a preparation checklist, **not a record that two phones have passed**. The coding agent did not access either phone, execute these steps, run new tests or rebuild an APK for this documentation task.

## Choose and verify the actual build

- [ ] Confirm the same intended Android APK is installed on both phones. Do not assume a local/showcase/cloud-test APK is the online app.
- [ ] The recorded October 26 online artifact is `build/phone-release/20261026-prototype-gemini-d8c1/WhatMeal-release.apk`, package `com.example.whatmeal`, `productionRelease`, Firebase project `whatmeal-101`. Its recorded SHA-256 is `76060693292D9193D94EBFE245CFF3FEF8A6D20E0A74B39D5FCEBDB00832F623`. This identifies an existing artifact, not a new October 29 build.
- [ ] The current source removes the obsolete production debug-provider override. The October 26 artifact predates that source change but was recorded with the override **false**. Do not say the APK was rebuilt after removal.
- [ ] Install an update without uninstalling or clearing an existing account's data. Do not change phone users. Device actions belong to the presenters; no coding-agent phone access is implied.
- [ ] Native release startup uses Play Integrity; do not switch to a debug provider or change Firebase settings for the talk. `local`/`showcase` use local backends and deliberately block live AI/native push. `aitest`/`cloudtest` are separate debug-only test workflows, not this two-phone release demo.

## Accounts and authorization

- [ ] Use two **existing, authorized demonstration accounts**: A is household owner; B is member or admin with editing permission. Do not use the same account on both phones as evidence of two-user authorization.
- [ ] Both accounts are already email-verified and signed in. Test their actual sign-in before the timer. Registration and email delivery are deliberately outside the ten-minute live sequence.
- [ ] Confirm both belong to the same intended household. If joining is necessary, the owner creates one invitation through **Profile → Family Sharing → Create Invitation / Invite Member**. B uses **Join with Key → Invite Code / Key → Join Family Space**. Transfer and redeem it privately before presenting.
- [ ] Check invitation expiry, case-sensitive entry and single use; never include the real invitation in these documents, screenshots shared publicly or source control. Do not demonstrate leaving/rejoining by deleting a working membership during the talk.
- [ ] Confirm both show the correct household, profiles, saved plans, pantry and groceries. Personal records are not automatically copied into a household when joining.
- [ ] View Only cannot perform the planned shared edits. Household account members and planned-for family profiles are different records; do not confuse them.
- [ ] Do not edit, archive, delete, remove members from, or transfer ownership of unrelated households.

## Fill a private cue card with real records

No account, password, provider key, recipe, household or ingredient record is invented by this guide. Select actual records with the account owner's agreement.

| Needed selection | What the team must record privately |
|---|---|
| Household and accounts | Real household name; which presenter holds A/B; confirm their roles. Do not write passwords on a public card. |
| Planned-for profile | Existing profile ID/name, genuine preferences and restrictions, and a cuisine selected in the creator. Do not weaken an allergy to make a generated result pass. |
| Manual recipe | Actual reviewed dish name and ingredient text, a meaningful plan title, and chosen schedule date. Use one day and Dinner for speed. |
| Saved backup | Exact existing plan title/date, permission to open it on B, and the meal to inspect. Call it previously generated only if that is actually known. |
| Grocery example | Accepted meals with interpretable quantities, at least one fully covered ingredient and a separate real shortage if showing both sections. Partial coverage of a single ingredient does not guarantee an AVAILABLE section. If no covered requirement exists, show only the actual section present. |
| Completion example | An actual accepted saved meal with recorded recipe ingredients and sufficient current pantry coverage. Verify **Mark Completed → Confirm** in rehearsal. The pantry check can reject the action after confirmation; do not bypass that rejection. |
| Shared update item | An agreed noncritical pantry record and two legitimate rehearsed quantity values. Avoid disrupting another person's real inventory or the timed completion example. |
| Inbox example | A real historical notification to open if the new event is delayed. Distinguish it aloud from new delivery. |

## AI readiness before the timer

- [ ] On **Profile → AI Settings**, verify the actually selected provider and model. Do not show or copy secret fields publicly.
- [ ] The current source default model is `gemini-3.5-flash-lite`. Existing explicitly saved choices are not automatically replaced; confirm the actual selection.
- [ ] In the configured academic build, the existing credential pool uses the Gemini Developer API directly; a personal Gemini key takes priority. If neither is configured, the retained Firebase AI Logic route requires valid App Check. Do not claim every deployment uses the same path.
- [ ] Free-tier availability depends on the provider/project's quota and access. An app limit is not a promise of unlimited free generation. Shared prototype credentials inside an APK are extractable; this is not a secure commercial key-distribution architecture.
- [ ] If permitted, perform a small real generation and **save/reopen it through the installed app** during rehearsal. Record the actual provider/model, success/failure and whether the save completed. A successful **Test Connection** alone is insufficient.
- [ ] Preconfigure **one day, Dinner, a selected planned-for profile, at least one cuisine**. Cuisine is required by validation despite its nearby “Optional” caption. Verify loaded pantry/grocery feeds and synchronized provider settings.
- [ ] B has an accessible saved backup. By **03:25**, switch to B if A has not completed. Do not launch a second request. If only one phone is available or both are busy, omit live generation and say that the shown plan was saved earlier.
- [ ] Do not claim a fresh save if the result is still an in-memory draft. Use **Save Plan**, wait for confirmed success, reopen through **Saved → Load Plan**, check date and meal identity.

## Connectivity and two-phone rehearsal

- [ ] Use stable internet on both phones for the online Firebase/AI demo. Confirm Wi-Fi/mobile data before starting; configure screen mirroring before the timer.
- [ ] Keep both apps foregrounded for the sharing/inbox check. Native background push is a separate, unverified workflow and is not required here.
- [ ] With B already a member and watching Pantry, A edits the agreed item. Observe the new quantity on B before calling synchronization successful. Do not use A for this step if an earlier request/save is pending or a new draft is unsaved; retain it and label the new check NOT RUN.
- [ ] On B, note the unread/newest-event baseline, then identify the **Pantry** event created after Jobert's shared update and tap it. Earlier pantry edits have the same generic title/body. Confirm read state and routing back to Pantry. A's own pantry event excludes its actor; do not use A's inbox as evidence of fan-out failure.
- [ ] New members do not receive all older household activity: the feed filters against membership `joinedAt`. Create the test update after B has joined.
- [ ] Record **PASS / FAIL / NOT RUN** separately for A launch, B launch, sign-in, manual save/reopen, AI generation, AI save/reopen, calendar date, grocery update, cross-account quantity refresh, and inbox routing. Do not fill PASS from this document.

## Timing and recovery

- [ ] One timer runs continuously for 10:00. Jabez stops at02:30, Leonard05:00, Kyle07:30, Jobert10:00, including transitions.
- [ ] Rehearse the actual recipe entry; do not type an entire long recipe live. Preconfigure only the settings allowed by the script; do not silently pre-save the result and call it a new successful write.
- [ ] AI progress is non-dismissible. It has no Cancel button. Provider request timeout does not bound every preceding database/settings operation.
- [ ] If A is stuck, leave it alone and use B's real backup. Do not pretend that closing an error or seeing an editor proves generation or persistence.
- [ ] Failed **or still-pending/unconfirmed** saves require the same timed fallback: at01:45 for Jabez or03:55 for Leonard, leave A's save/editor untouched and use B. Do not select **Discard**. Retry only after the timed demo unless the allotted slot permits one clear recovery.
- [ ] Retry a failed data feed through its actual Retry control; do not repeatedly tap a disabled action, clear data or dismiss system failures to hide them.
- [ ] Missing image: continue with the intentional fallback and recipe text. No photo source guarantees a matching photograph for every dish.
- [ ] If behind, omit extra month navigation or a new manual grocery item. Preserve the four equal time allocations.
- [ ] End at10:00. The Q&A guide is a study resource, not an extra scripted segment.

## Evidence and known limitations

| Area | Current evidence | What remains unverified/limited |
|---|---|---|
| Automated application checks | Recorded October26 full suite: 675 passes, one skip; clean analysis. October28 cleanup:31 focused Flutter passes,6 web/bootstrap passes, analysis of `lib/main.dart` clean. | These do not prove two physical phones, live Firebase listeners, or every provider/model. No tests rerun for these documents. |
| Authorization | Recorded71-case Firestore emulator acceptance; canonical membership, role/schema cases. | Not a new physical-device or production-data acceptance session. |
| Live AI/persistence | October26 bounded host proof: five small credential probes, one `gemini-3.5-flash-lite` meal, isolated Spark repository/REST save/reopen. | Not a release-APK UI proof; no claim all five credentials generated full plans or all models/providers work live. |
| Android | Existing APK build/signature/hash and older emulator workflows. User reports the app is working. | Coding agent performed no new two-phone acceptance. User-observed results must be labeled user-verified. |
| Notifications | In-app activity/receipt/routing implementation and automated evidence. | Background/cold-start native push delivery and trusted sending infrastructure not fully verified. |
| Stock behavior | Quantity matching/projection tests and source. | Grocery checks do not add pantry stock; completion does not deduct it; manual duplicate names are not quantity aggregation. |
| Profile recovery | Account-profile retry and Home recommendation feed recovery implemented. | Profile's family-member list does not itself expose all repository loading/error states. Avoid forced-outage demonstration. |
| Security | Release Play Integrity retained; Auth and Firestore rules remain distinct controls. | Historical App Check debug credential exposure remains unresolved; the owner explicitly accepted that known Git-history risk for the push. No secrets were revoked by this documentation task. |

Detailed prior evidence: `audit/final/ACADEMIC_RELEASE_20261026.md`; current trace and limitations: `CODE_DEFENSE_GUIDE.md`. Do not claim production readiness during an academic presentation.
