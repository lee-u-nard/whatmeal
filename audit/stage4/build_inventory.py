"""Generate the checkpoint inventory; statuses do not certify live Firebase behavior."""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rows = []

def group(area, source, code, body):
    assert (ROOT / code).exists(), code
    for line in body.strip().splitlines():
        feature, expected, status, evidence, action = line.split('|')
        rows.append(dict(id=f'R{len(rows)+1:03}', area=area, source=source,
                         feature=feature, expected=expected, code=code,
                         status=status, evidence=evidence, action=action))

group('Authentication', '4–5, 34–36', 'lib/features/auth/data/auth_repository.dart', '''
Registration and login|Authenticate by Firebase UID with validated forms|UNVERIFIED|Source traced; no live Auth exercise|Test failed profile creation after successful registration
Password management|Use Firebase Auth only; never store passwords in Firestore|UNVERIFIED|Source uses Auth; no device exercise|Test reauthentication and provider-specific accounts
Email verification and reset|Deliver verification and reset workflows|UNVERIFIED|Source inspection only|Exercise expired links and recovery
Logout|Confirm and clear account-scoped state|PARTIALLY IMPLEMENTED|Confirmation and repository resets exist|Test rapid A to B switching on devices
Profile persistence|Keep Auth and profile data consistent|PARTIALLY IMPLEMENTED|Login can rewrite display name from Auth|Resolve authority and failure recovery
Account isolation callbacks|Reject every old-session callback|PARTIALLY IMPLEMENTED|Some Auth callbacks lack generation guards|Add delayed old-session error and same-UID reentry tests
Safe Auth errors|Show useful errors without sensitive details|PARTIALLY IMPLEMENTED|Raw exception paths remain|Complete redaction review
''')
group('Household security', '6–11, 46–49', 'lib/core/services/family_service.dart', '''
Canonical membership|Use family members plus private membershipIndex|UNVERIFIED|Local v2 service and fake-store tests; emulator BLOCKED|Run real rules acceptance suite
Household bootstrap|Atomically create owner and index|UNVERIFIED|Local transaction implementation|Test concurrent creation under real rules; BLOCKED
Owner permissions|Reserve ownership and lifecycle operations|UNVERIFIED|Local rules matrix; emulator BLOCKED|Prove allowed and denied operations
Admin permissions|Manage allowed membership without ownership escalation|UNVERIFIED|Local rules matrix; emulator BLOCKED|Test owner protection and invitation role bounds
Member permissions|Edit shared content without managing authority|UNVERIFIED|Local rules matrix; emulator BLOCKED|Run permission matrix
View-only permissions|Read shared content without mutation|UNVERIFIED|Local rules matrix; emulator BLOCKED|Exercise every content path
Outsider and anonymous isolation|Deny unauthorized household access|UNVERIFIED|C01/C02 remain open; emulator BLOCKED|Prove direct and query denials
Member removal and leave|Atomically revoke member and index without private-user writes|UNVERIFIED|Local v2 transactions and tests|Real rules plus active-listener revocation tests; BLOCKED
Ownership transfer|Offer and explicitly accept atomic transfer|UNVERIFIED|Local expiring transfer flow|Race, expiry and immutable-owner tests; BLOCKED
Archive and restore|Preserve household data instead of hard deletion|UNVERIFIED|Local lifecycle behavior|Owner and multi-member real-rules tests; BLOCKED
Legacy cutover|Fail closed without restoring permissive legacy access|UNVERIFIED|Local cutover notice and v2 requirements|Migration rehearsal separately approved; BLOCKED
Secure invitations|Generate strong expiring single-use tokens|UNVERIFIED|Local token and transaction tests only|Redemption, reuse, expiry, revocation and concurrent joins; BLOCKED
Invitation confidentiality|Prevent token enumeration and unauthorized generation|UNVERIFIED|Local rules constraints|Emulator outsider, recipient binding and role injection tests; BLOCKED
Strict schemas|Reject unknown fields and immutable authority changes|UNVERIFIED|Local v2 field allowlists|Compile rules and execute injection suite; BLOCKED
''')
group('Profiles and preferences', '12–14, 17', 'lib/features/profile/data/family_member_repository.dart', '''
Dependent profile CRUD|Preserve names, ages, relationships and dietary data|PARTIALLY IMPLEMENTED|Edit form reconstruction can reset creation metadata; removal feedback precedes completion|Preserve metadata and await writes
Allergy and dietary context|Include applicable restrictions in generation|PARTIALLY IMPLEMENTED|Generation passes restrictions; replacement context is narrower|Test all selected participants and custom notes
Participant identity|Persist stable selected participant IDs|BROKEN|Plan creation assigns member names to selectedMemberIds|Use stable IDs and define old-data compatibility
Unset cuisine|Keep recommendations blank until preferences exist|CONFLICTING|Current generation treats unset as Any|Resolve requirement versus current behavior explicitly
Empty household|Avoid invented member preferences|UNVERIFIED|Empty states exist in source|Device test new and newly joined accounts
''')
group('Pantry', '15', 'lib/features/pantry/pages/pantry_page.dart', '''
Ingredient add and delete|Persist changes and report failures accurately|PARTIALLY IMPLEMENTED|Some handlers still report success before awaited completion|Await writes and test failures
Category edit|Update the existing ingredient without delete-create data loss|UNVERIFIED|Repaired to await same-document update|Verify Firestore rules and concurrent edits
Edit metadata and expiry|Retain identity, author, creation time and exact expiry|IMPLEMENTED|Two passing pantry widget regressions cover metadata and expired date picker|Live persistence remains unverified
Shared pantry synchronization|Scope live ingredient streams to active household|UNVERIFIED|Repository listener guards exist|Two-device removal and account-switch tests
Availability for AI|Use actual available ingredients consistently|PARTIALLY IMPLEMENTED|Pantry context exists; expiry/status policy needs reconciliation|Define expired/used eligibility tests
''')
group('Grocery lists', '16, 60–66', 'lib/features/grocery/data/grocery_repository.dart', '''
List initialization|Avoid concurrent duplicate initial lists|UNVERIFIED|Stable initialization implementation with fake-store tests|Real contention and rules tests
Item duplicate prevention|Normalize and atomically prevent duplicate items|UNVERIFIED|Store tests pass; no live contention proof|Emulator concurrent additions and retry tests
Item editing|Edit existing grocery items|MISSING|No item-edit method or UI located|Implement within existing list design
Mutation feedback|Report delete and duplicate outcomes correctly|BROKEN|Delete feedback is premature; duplicate no-op can report added|Await writes and expose actual outcomes
Check and uncheck|Persist item completion and shared updates|UNVERIFIED|Source paths exist|Cross-device and failure tests
Active list lifecycle|Follow parent list changes and deletion|PARTIALLY IMPLEMENTED|Parent selected once|Observe active parent and recover after deletion
Viewer initialization|Read without attempting unauthorized creation|PARTIALLY IMPLEMENTED|First-open initialization may create a list|Test view-only empty household path
Generation from meals|Create needed ingredients with clear provenance|PARTIALLY IMPLEMENTED|Generation exists; deletion associations incomplete|Define exact plan-item provenance
AI ingredient meaning|Do not treat needed groceries as already available|BROKEN|Needed grocery names are combined with pantry context|Separate available and shopping-needed prompt fields
''')
group('AI providers', '19–23, 45', 'lib/features/ai_settings/data/ai_provider_repository.dart', '''
Supported provider protocols|Use explicit adapters and reject arbitrary compatibility claims|PARTIALLY IMPLEMENTED|Custom OpenAI Chat Completions adapter tests pass|Live Gemini, Groq, OpenAI and Anthropic remain unverified
Remote provider settings|Apply account-scoped configuration updates|UNVERIFIED|New injected-stream tests pass; real Firestore not exercised|Verify two-device updates and deletion
Pending settings writes|Serialize edits and reject stale echoes|IMPLEMENTED|New tests cover queueing and newer remote snapshot precedence|Real backend contention still unverified
Account settings isolation|Detach old account streams and delayed saves|IMPLEMENTED|Tests cover A to B and A to B to A|Audit LlmService cache refill after old dispatched writes
Key removal feedback|Restore Gemini and show success only after persistence|IMPLEMENTED|Repository and widget tests include failed removal and retry|Live key validation is separate
Settings editor synchronization|Refresh endpoint and clear stale secret editor|IMPLEMENTED|Widget test exercises remote update and logout|No OS-vault migration performed
Settings failure recovery|Clear stale credentials and expose safe failures|PARTIALLY IMPLEMENTED|Error and recovery tests pass on injected streams|Provide explicit resubscription for terminal listener failures
Connected status|Only claim validated connectivity|PARTIALLY IMPLEMENTED|Loaded or saved keys can show Connected before validation|Separate configured from verified
Provider change notifications|Publish only confirmed changes|PARTIALLY IMPLEMENTED|Callback can run before persistence succeeds|Move event after confirmed save with scope guard
Secure API key storage|Prefer device secure storage with approved migration|PARTIALLY IMPLEMENTED|Existing private Firestore storage retained|OS-vault migration and cross-device trade-off need approval
Error redaction|Never expose keys or raw sensitive exceptions|PARTIALLY IMPLEMENTED|Some raw adapter and UI exception paths remain|Complete boundary-by-boundary redaction tests
Quota reservation|Reserve usage transactionally; retain failed reservations|UNVERIFIED|Fake-store reservation tests pass|Real rules and concurrent requests; client quota is cooperative
Output validation|Reject malformed output and normalize structured meals|IMPLEMENTED|Parser regression tests pass|Actual nutritional and allergy correctness not guaranteed
Provider network failures|Handle timeouts, limits and malformed responses|UNVERIFIED|Mock adapter coverage only|Isolated live provider checks with user-supplied credentials
''')
group('Meal plans', '17–18, 24–33', 'lib/features/meal_plan/data/saved_plans_repository.dart', '''
Manual plan content|Save meaningful manually entered meals|PARTIALLY IMPLEMENTED|Blank slots can be saved and fixed macros are supplied|Validate meal completeness; remove fabricated nutrition
Weekly calendar|Organize Monday through Sunday accurately|IMPLEMENTED|Date and model regression coverage|Device layout still unverified
AI planning workflow|Honor people, meals, days, budget and ingredients|UNVERIFIED|Source traced; no live generation exercise|End-to-end configured-provider test
Accept and meal statuses|Persist pending, accepted, completed and not-completed states|PARTIALLY IMPLEMENTED|Saved-view conversion can lose saved-plan identity|Trace draft versus persisted edit paths
Replacement concurrency|Produce one successor per replacement operation|UNVERIFIED|Transaction store tests pass|Emulator contention and authorization tests
Replacement context|Carry full participant and preference context|PARTIALLY IMPLEMENTED|Replacement context omits some original generation preferences|Preserve selected IDs and complete context
Repeated save|Avoid duplicate plans under rapid taps|PARTIALLY IMPLEMENTED|No complete in-flight guard located|Add idempotent save behavior and test failure recovery
Nested saved-plan synchronization|React to meal-only updates without parent writes|UNVERIFIED|Nested stream fake-store tests pass|Two-device real Firestore verification
Account-safe plan mutations|Reject stale optimistic updates after account switch|PARTIALLY IMPLEMENTED|Several post-await updates lack captured-scope checks|Delayed same-ID account-switch tests
Personal/shared merge identity|Avoid collisions between document namespaces|PARTIALLY IMPLEMENTED|Plans merged using ID only|Use scope-aware identity
Plan deletion grocery cleanup|Remove associated shared grocery state safely|BROKEN|Cleanup scans personal lists and misses shared associations|Use exact provenance; avoid destructive guessing
Plan deletion notification cleanup|Remove only associated notification state|PARTIALLY IMPLEMENTED|Title-substring fallback can match unrelated records; shared activity immutable|Define retention and stable plan linkage
Today recommendations|Show meals for the actual current date|BROKEN|Home uses first active saved meals without date filtering|Apply date-aware selection and regression tests
Recipe details and images|Render ingredients, instructions and graceful image fallbacks|UNVERIFIED|Source paths exist|Network failure and device render checks
Reuse, favorite and history|Preserve plan data and persisted interactions|PARTIALLY IMPLEMENTED|Paths exist; saved-view edits and stale updates need repair|Exercise complete saved-plan lifecycle
''')
group('Notifications', '37–42', 'lib/core/services/notification_service.dart', '''
Shared activity and private receipts|Avoid unauthorized per-member fan-out writes|UNVERIFIED|Local activity store and receipt tests pass|Real rules suite BLOCKED; H08 not live verified
History, read state and badge|Combine private and authorized household events|UNVERIFIED|Source and fake-store coverage|Two-device receipt and badge tests
Join-time eligibility|Exclude historical activity from before membership|IMPLEMENTED|Activity store regression tests pass|Security enforcement remains emulator BLOCKED
Event reliability|Preserve useful content and avoid lost/duplicate events|PARTIALLY IMPLEMENTED|Domain and event writes often separate; generic text loses detail|Add stable operation IDs and failure tests
In-app notification navigation|Open the authorized target from history|MISSING|Card tap only marks read|Add guarded route navigation
Foreground notification tap|Route local notification taps with payload|MISSING|Initialization lacks response callback and payload path|Add plugin-level tap tests
Cold-start navigation|Wait for authentication and membership readiness|PARTIALLY IMPLEMENTED|One post-frame attempt; no queued readiness flow|Test terminated-app launch and account switch
Payload route validation|Reject unsupported notification targets|IMPLEMENTED|Pure route tests pass|Device navigation remains unverified
Background household delivery|Provide reliable household push when app is closed|MISSING|No approved trusted sender architecture|Requires separate product/architecture decision; no paid service introduced
Offline and reconnect|Recover subscriptions without stale state or false success|PARTIALLY IMPLEMENTED|Firestore persistence and some guards exist|Real offline, reconnect, removal and account-switch tests
''')
group('Release and governance', '1–3, 43–80', 'README.md', '''
Original design and branding|Preserve logo, colors and existing visual identity|UNVERIFIED|Changes localized; no redesign performed|Visual device regression checks pending
Confirmations and interaction states|Confirm significant actions and expose loading/error/empty states|PARTIALLY IMPLEMENTED|Several flows covered; premature success remains elsewhere|Audit remaining destructive handlers and accessibility
Local-only boundary|Do not deploy, migrate production or enable paid services|IMPLEMENTED|This stage uses local files and automated tests only|Production migration and deployment remain separate approvals
App Check and platform configuration|Use configured attestation and release identity|PARTIALLY IMPLEMENTED|Release signing and attestation setup remain pending|Manual console/signing verification without exposing secrets
Android release build|Build a distributable release safely|UNVERIFIED|Prior Gradle loopback failure; no justified remedy; BLOCKED|Diagnose on host with functioning Java networking
Emulator security certification|Actually execute all role, invitation and injection tests|UNVERIFIED|Java selector startup blocked; zero assertions; BLOCKED|Run existing acceptance suite in supported local environment
iOS and web readiness|Verify supported platform configuration and builds|UNVERIFIED|Windows cannot verify iOS; web requires configured site key|Platform-specific build and device checks
SDK compatibility|Keep declared minimum compatible with used APIs|PARTIALLY IMPLEMENTED|Old Dart minimum with newer API use|Determine and validate actual minimum
Complete end-to-end parity|Exercise all household workflows with two accounts|UNVERIFIED|Unit/widget passes do not establish live functionality|Run owner/member/viewer, offline and failure-recovery scenarios
Historical status reconciliation|Retain evidence without treating old plans as current guarantees|IMPLEMENTED|Stage 3 supersedes pending local design; C01/C02 still unverified|Do not rewrite historical results or call audit complete
''')

counts = Counter(r['status'] for r in rows)
blocked = sum('BLOCKED' in r['evidence'] or 'BLOCKED' in r['action'] for r in rows)
(ROOT/'audit/stage4/requirements.json').write_text(json.dumps(rows, indent=2)+'\n', encoding='utf-8')
out = ['# WhatMeal functionality reconciliation — local checkpoint', '',
       'Updated 2026-10-06. Source: [user-supplied project context](WHATMEAL_CONTEXT.md), with the explicit local-only security approval taking precedence. The shared conversation was only partially accessible; the pasted context supplies the requirements. This is a grouped behavior inventory, not a claim that every visible interaction has been exercised.', '',
       f'{len(rows)} tracked requirement groups. '+ '; '.join(f'{k}: {v}' for k,v in sorted(counts.items()))+f'. BLOCKED: {blocked} (overlapping evidence flag, not an additional status).', '',
       '**IMPLEMENTED** means the specific bounded behavior has supporting automated or inspection evidence. It never implies live Firebase, provider, device or deployment verification. **UNVERIFIED** means implementation exists or a gate is known, but the required environment/evidence is absent. Other statuses identify a concrete gap. C01/C02 remain OPEN/UNVERIFIED.', '',
       'Conflicts: unset cuisine currently means Any despite the requested blank state; historical short-code/hard-delete approaches are superseded by the approved local v2 design. Secure-storage preference is not approval for a breaking credential migration. Private receipt IDs are namespaced to avoid event collisions. Reliable background delivery still requires an approved sender design.', '']
for area in dict.fromkeys(r['area'] for r in rows):
    out += [f'## {area}', '', '| ID / behavior | Source sections | Expected behavior | Code | Status | Current evidence | Remaining action / edge case |', '|---|---|---|---|---|---|---|']
    for r in rows:
        if r['area'] == area:
            out.append(f"| {r['id']} {r['feature']} | Context §{r['source']} | {r['expected']} | [{Path(r['code']).name}]({r['code']}) | {r['status']} | {r['evidence']} | {r['action']} |")
    out.append('')
out += ['## Workflow verification still required', '',
        '1. Register/login → create or join household → switch accounts → prove all old listeners and private state clear.',
        '2. Owner/admin invitation → simultaneous redemption → revocation, expiry, reuse and unauthorized role attempts.',
        '3. Profiles/preferences → pantry/grocery → generate/manual plan → accept → replace → save → complete.',
        '4. Saved nested meal change → second device → exact associated grocery and notification cleanup.',
        '5. Shared event → private receipt → badge → foreground/background/cold-start navigation.',
        '6. Offline edit → failure/retry/reconnect → member removal/archive → stale-cache isolation.', '',
        'Maintain this file through `audit/stage4/build_inventory.py`; machine-readable rows are in `audit/stage4/requirements.json`. See [repair and verification report](audit/stage4/REPORT.md). Further inspection may split groups and uncover additional issues; counts are not counts of proven security vulnerabilities.', '']
(ROOT/'WHATMEAL_FUNCTIONALITY.md').write_text('\n'.join(out), encoding='utf-8')
print(json.dumps(dict(total=len(rows), statuses=counts, blocked=blocked)))
