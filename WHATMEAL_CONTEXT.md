# WhatMeal — Project Context & Complete Requirements

> This document is the persistent project context for WhatMeal.
> It records the product requirements, decisions, architecture, constraints,
> known issues, verification limits, and important historical decisions
> established during development.
>
> Codex/AI agents MUST read this file before making substantial changes to WhatMeal.
>
> IMPORTANT:
> - This document describes the intended product and known project history.
> - The actual codebase remains the implementation source of truth.
> - Do not assume a feature works merely because it is listed here.
> - When requirements conflict with the current implementation, audit the implementation
>   and report the discrepancy.
> - Do not silently remove or reinterpret requirements.
> - Do not redesign the product unless explicitly requested.

---

# 1. PROJECT IDENTITY

## Product Name

**WhatMeal**

## Project Type

WhatMeal is a **course Application Development project**, not a thesis.

## Technology

Primary stack:

- Flutter
- Dart
- Firebase
- Firebase Authentication
- Cloud Firestore
- Firebase AI / Gemini
- Firebase Cloud Messaging
- Firebase App Check

The project is intended to remain compatible with the Firebase Spark/free-tier constraints unless explicitly approved otherwise.

## Main Purpose

WhatMeal is an AI-assisted household meal-planning application.

It helps users:

- manage household members
- manage family dietary information
- manage pantry ingredients
- manage grocery items
- generate meal recommendations
- generate weekly meal plans
- replace/regenerate meals
- save meal plans
- track meal completion
- receive household activity notifications
- synchronize shared household information in real time

The application should work for an individual user as well as households/families.

---

# 2. CORE PRODUCT PRINCIPLE

WhatMeal should behave as a **shared household workspace**.

A household owner and authorized household members should be able to work with the same household data according to their assigned permissions.

Shared information may include:

- family profiles
- dietary restrictions
- preferences
- pantry
- grocery list
- meal recommendations
- meal plans
- saved plans
- meal statuses
- household activity
- notifications related to household activity

A member should not be treated as an isolated copy of the household.

If an authorized member changes shared household data, other authorized household members should eventually see the same change.

Where real-time synchronization is intended, use Firestore listeners rather than relying only on one-time reads.

---

# 3. ACTORS AND ROLES

The application supports household roles.

Expected roles:

- Owner
- Admin
- Member
- View-only member

## Owner

The household owner has the highest household-level permissions.

Expected capabilities include:

- manage household
- invite members
- manage roles according to role rules
- manage household data
- manage members
- perform owner-only operations
- transfer ownership where supported
- archive/restore household where supported

## Admin

Admins can perform administrative household operations allowed by the role matrix.

Admins must NOT automatically receive owner privileges.

In particular:

- admin permissions must be explicit
- owner-only operations remain owner-only
- admin cannot arbitrarily modify ownership
- admin invitation capabilities follow the approved invitation policy

## Member

Members can use shared household functionality according to the role matrix.

A member should be able to participate in:

- meal planning
- family information
- pantry
- grocery
- recommendations
- shared household workflows

where permitted.

## View-only

View-only users must not be able to perform writes that the role does not permit.

A recursive/general write permission must never override role-specific restrictions.

---

# 4. AUTHENTICATION

Authentication is based on Firebase Authentication.

## Required authentication functionality

The application should support:

- registration
- login
- logout
- session restoration
- authentication state listening
- account isolation
- profile synchronization
- password management
- authentication error handling
- account switching

## Registration

A new user should:

1. create a Firebase Authentication account
2. receive a unique Firebase UID
3. have their application profile associated with that UID
4. have no access to another user's private data

## Login

After login:

- the app must load the authenticated user's data
- household scope must be determined from the authenticated UID
- stale data from a previous account must not remain visible

## Logout

Logout is a consequential action.

The application should display a confirmation such as:

> Are you sure you want to log out?

After logout:

- Firebase Auth session is cleared
- account-scoped repositories/listeners are reset
- household-scoped listeners are stopped
- cached account data must not leak into the next account
- notification/token cleanup must occur according to the implemented architecture

## Account switching

The following scenario must be safe:

```text
Account A login
↓
Account A data loaded
↓
Logout
↓
Account B login
↓
Account B data loaded
```

Account B must NOT see:

Account A's household
Account A's meal plans
Account A's notifications
Account A's provider credentials
Account A's pantry
Account A's grocery list
Account A's family data
5. USER PROFILE

Each Firebase UID owns its own profile.

Profile information may include:

username/display name
email
profile information
application preferences
AI provider settings that are not secret
Profile synchronization

Changes made in Firebase should eventually appear in the application.

Changes made in the application should update Firebase.

For realtime profile fields:

Firestore
↓
listener
↓
application state
↓
UI

The application must not depend permanently on stale in-memory profile data.

Password

Passwords belong to Firebase Authentication.

DO NOT store plaintext passwords in Firestore.

Password changes must use Firebase Authentication mechanisms.

6. HOUSEHOLDS

Households are the main shared scope of the application.

A user can belong to a household.

Household membership determines access to shared data.

Household functionality

Expected functionality includes:

create household
join household
invite users
redeem invitations
manage members
assign roles
remove members
leave household
ownership transfer
archive household
restore household
invitation expiration
invitation revocation
single-use invitations
rejoin behavior
concurrent invitation redemption protection
7. APPROVED HOUSEHOLD SECURITY ARCHITECTURE

The intended security architecture is based on:

families/{familyId}
families/{familyId}/members/{uid}

membershipIndex/{uid}

householdInvitations/{token}

families/{familyId}/invitationRefs/{token}

families/{familyId}/activity/{eventId}

users/{uid}/notificationReceipts/{eventId}

These paths are part of the approved Stage 3 architecture.

Canonical membership

Canonical household membership should be represented by:

families/{familyId}/members/{uid}

This should contain role/membership information.

UID navigation index

The application may use:

membershipIndex/{uid}

to efficiently determine household membership.

The index must not become an authorization bypass.

Authorization must still be based on canonical membership/security rules.

8. HOUSEHOLD INVITATIONS

Invitation security is critical.

The intended architecture uses:

householdInvitations/{token}

and:

families/{familyId}/invitationRefs/{token}
Invitation requirements

Invitations should:

use strong random tokens
be single-use
expire
optionally bind to a recipient UID
not expose unnecessary household data
not allow arbitrary household enumeration
not allow users to add themselves to households without invitation proof

The intended token strength is approximately:

192-bit random capability

Default expiration:

48 hours

Maximum expiration:

7 days

Invitation rules

Owner/admin invitation capabilities must follow the approved role matrix.

Important policy:

owner may issue appropriate invitations
admin may issue invitations where allowed
only owner may issue admin invitations
invitations for owner role must never be created through normal invitation flow
Invitation redemption

Redemption should be atomic.

The system must prevent:

double redemption
concurrent redemption
token reuse
unauthorized household joining
role escalation
9. HOUSEHOLD OWNERSHIP

Ownership is protected.

A member must not be able to arbitrarily change:

createdBy
owner
role
membership

through unrestricted writes.

Ownership transfer must be explicit and atomic.

Do not implement ownership transfer as a casual field edit.

10. MEMBER REMOVAL / LEAVING

Member removal and leaving a household require careful synchronization.

When a member loses access:

their household listeners must stop
household data must disappear from active application state
future reads must be denied
future writes must be denied
cached state must not remain visible as current household state

Do not assume that client-side deletion can safely delete another user's private documents.

Where server-side cascading is unavailable because of Spark-only constraints, use an explicit client-safe unlink/archive protocol.

11. ARCHIVE / RESTORE

Household deletion should not automatically mean destructive hard deletion.

The approved direction is:

Archive
↓
Restore

rather than ordinary client-side hard deletion.

Any destructive migration requires explicit approval.

12. FAMILY / HOUSEHOLD MEMBERS

The application manages the people for whom meals are being planned.

Family profiles can include:

name
age/age category where supported
dietary restrictions
diet type
food preferences
allergies
custom allergy notes
other relevant meal-planning preferences
CRUD

Users should be able to:

add family member
edit family member
remove family member
view family members
AI integration

Family information must be used when generating recommendations/meal plans.

AI should account for:

allergies
dietary restrictions
preferences
diet
custom allergy notes

Replacement/regeneration operations should also preserve relevant dietary context.

13. NEW HOUSEHOLD / EMPTY HOUSEHOLD BEHAVIOR

A newly created household should not randomly display meal plans or recommendations.

If no family members exist:

meal plan should be blank where appropriate
recommendations should not invent household-specific data
UI should communicate that setup is needed

Similarly, recommendations should not appear simply because the app loaded.

14. CUISINE PREFERENCE

The application supports cuisine preference.

Expected examples include:

Philippines
global/international cuisine

For a new user/household:

cuisine preference may initially be unset
recommendations should remain blank rather than inventing a preference

Once selected, the preference should influence AI generation.

15. PANTRY

Pantry represents ingredients currently available to the household.

Examples:

onion
garlic
vegetables
meat
rice
other available ingredients
Pantry functionality

Users should be able to:

add ingredients
edit ingredients
delete ingredients
view ingredients
use pantry information in AI generation

Pantry is household-scoped.

Authorized household members should see shared pantry state.

16. GROCERY LIST

The grocery list represents ingredients/items needed by the household.

Grocery functionality

Users should be able to:

create/access grocery list
add item
edit item
delete item
check item
uncheck item
generate grocery list
synchronize changes
use grocery information for meal generation
Initialization

Grocery initialization must be stable.

The system should prevent accidental duplicate initialization.

Known Stage 2 work addressed:

stable default list initialization
normalized deterministic new item IDs
transactional existence checks
legacy duplicate detection
account-scope guards

However:

old clients may still create random-ID duplicates
existing duplicates may not automatically be consolidated
active-list selection was not fully verified across all scopes

Do not assume grocery concurrency is fully verified until actual emulator/device testing succeeds.

17. AI MEAL RECOMMENDATIONS

WhatMeal uses AI to recommend meals.

Default provider:

Gemini / Firebase AI

Optional custom providers may also be supported.

Recommendation inputs

AI recommendations should consider:

family members
allergies
dietary restrictions
diet types
food preferences
cuisine preference
pantry ingredients
grocery ingredients
available ingredients
household context
meal/date context where applicable

The user explicitly wants ingredients such as onion, garlic and vegetables to be considered when relevant.

Empty recommendation behavior

If required setup information has not been provided, do not invent arbitrary personalized recommendations.

18. AI MEAL IMAGES

Every recommended meal should have an image.

The image implementation may use:

an image service
a supported photo API
another approved implementation

Previously considered:

Unsplash photo API
placeholders

Do not introduce a paid service without approval.

If an image provider is unavailable, the UI should fail gracefully rather than breaking the entire meal workflow.

19. AI PROVIDERS

Default provider:

Gemini

Users may import/configure other providers where supported.

Known intended examples include:

Groq
OpenAI-compatible/custom providers

The system should support free or paid providers according to the provider's own API capabilities.

Provider switching

When switching provider:

selected provider must update
model must correspond to provider
endpoint must correspond to provider
old credentials must not accidentally remain active
stale in-memory credentials must not be used
provider settings must synchronize correctly
Provider removal

When a custom provider is removed:

Custom provider removed
↓
Gemini becomes active/default fallback

The application must not continue using stale custom credentials.

20. API KEYS / CREDENTIAL SECURITY

API keys are sensitive.

Never:

print API keys in logs
display them in errors
expose them in UI unnecessarily
store passwords as plaintext
expose credentials through client-readable shared documents
Current historical state

The original implementation had:

SecureKeyStore

but this was an in-memory cache rather than a true OS-backed secure store.

A durable copy existed in:

users/{uid}/secrets/llmConfig

which was plaintext at the application layer.

This was identified as a security concern.

Preferred architecture

Preferred direction:

device-only OS-backed secure storage for secrets
synchronize only non-secret provider settings
provider/model/endpoint may be synchronized
secret API keys should not need to be stored as ordinary readable Firestore data

Do not implement custom cryptography.

Do not automatically delete the only working credential during migration.

If secure storage is unavailable, do not silently fall back to insecure plaintext storage.

21. CUSTOM PROVIDER PROTOCOL

Custom provider support should explicitly document the protocol.

For OpenAI-compatible providers, the application should use the OpenAI Chat Completions contract.

Important behaviors:

correct endpoint construction
URI path/query handling
reject embedded URL credentials
require a valid chat response
handle HTTP errors safely
redact provider response bodies from user-visible errors/logs

Do not claim arbitrary provider compatibility if the adapter only supports OpenAI-compatible request/response format.

22. AI QUOTA

Gemini/default AI generation has a daily quota mechanism.

Stage 2 implemented reservation logic using a transaction.

Expected behavior:

reserve quota atomically
prevent concurrent requests from exceeding the cooperative limit
dispatch generation
handle failed/ambiguous requests safely

Known limitation:

failed/ambiguous requests may consume the reservation
quota remains cooperative
clock/counter manipulation may still be possible under current rules
contention has not been fully verified in the real environment

Do not claim quota protection is fully production-secure without appropriate rule/backend enforcement.

23. AI OUTPUT VALIDATION

AI output must be validated.

Validation should detect:

incomplete meal slots
duplicate meals where duplicates are not allowed
incorrect replacement day
invalid replacement slot
malformed meal data
missing required fields

Validation prevents malformed AI output from silently entering application state.

Validation does NOT automatically guarantee:

nutritional correctness
medical safety
allergy safety

The application must still provide appropriate safety/error behavior.

24. MEAL PLANNING

Meal planning is one of the primary WhatMeal workflows.

The weekly plan follows:

Monday
Tuesday
Wednesday
Thursday
Friday
Saturday
Sunday

Meal plans should be date-aware.

Meal entries should contain the appropriate:

date/day
meal type
meal information
status
household context
relevant metadata
25. MEAL TYPES

Meal planning may contain meal types such as:

breakfast
lunch
dinner
other supported meal categories

The exact supported categories must follow the current application UI/code.

Do not invent additional categories unless required.

26. MEAL STATUS

Meals can have states including:

Pending
Accepted
Completed
Not Completed

The UI and backend must consistently use the same state semantics.

27. ACCEPT MEAL

A recommended/pending meal can be accepted.

Expected flow:

Pending
↓
Accept
↓
Accepted

Acceptance should synchronize to authorized household members.

28. COMPLETE MEAL

A meal can be marked completed/done.

Expected flow:

Accepted
↓
Complete
↓
Completed

The exact allowed transitions should follow the current implementation and requirements.

29. NOT COMPLETED

A meal can also be marked as not completed.

This state should be synchronized like other meal status changes.

30. REPLACE / REGENERATE MEAL

Users can replace or regenerate a meal.

Replacement must:

preserve the correct day
preserve the correct meal slot
use the appropriate household/family context
use dietary restrictions/preferences
prevent duplicate successor creation under concurrency
31. REPLACEMENT TRANSACTIONS

Stage 2 implemented transactional replacement behavior.

Expected safeguards include:

predecessor checked
successor created once
slot retained
parent existence checked
explicit-ID retry idempotency
generated ID returned to caller

However:

real concurrent emulator/device verification was blocked
old/malicious writers are not automatically constrained by unchanged security rules

Do not mark this fully verified until actual concurrency testing succeeds.

32. SAVED MEAL PLANS

Users can save meal plans.

Saved plans should preserve the exact plan that was saved.

Saved plan functionality

Users should be able to:

save plan
view saved plan
reuse saved plan where supported
delete saved plan
View

The View button must open the exact saved plan rather than a newly generated or unrelated plan.

Delete

Deleting a saved plan must clean up its associated state as required.

For example:

Saved plan deleted
↓
associated recommendation/state removed where applicable
↓
pending counts updated

Do not leave orphaned recommendation state.

33. SAVED PLAN REALTIME SYNC

Nested meal changes should be reflected even if the parent saved-plan document is not edited.

Stage 2 added nested listeners for:

status changes
favorite changes
add/delete changes

Listeners should support:

cancellation
account/household scope guards
recreation after deletion/recreation

Known limitation:

offline behavior
permission recovery
multi-device behavior
large-feed cost behavior

have not been fully verified.

34. REALTIME SYNCHRONIZATION

WhatMeal is intended to use Firestore realtime listeners for shared data.

Important synchronized areas include:

household membership
profile where applicable
family data
pantry
grocery
meal plans
saved plans
notifications
household activity
Listener requirements

Listeners must:

be scoped to the authenticated UID/household
stop when scope changes
stop after logout
stop after membership revocation
avoid stale callbacks
not update UI with data belonging to a previous account
35. ACCOUNT-SWITCH STALE STATE

This is a critical requirement.

Potential bad flow:

Account A
↓
listener active
↓
logout
↓
Account B
↓
Account A listener still emits
↓
Account A data appears in Account B

This must never happen.

Use:

auth-scoped repositories
listener cancellation
generation/session guards
UID checks
household-scope checks
36. OFFLINE / RECONNECT

Firestore offline behavior must be considered.

When connectivity is lost:

UI should not crash
local state should not be mistaken for confirmed server state
pending writes should be handled appropriately
listeners should recover after reconnect
permission changes after reconnect must be handled

Full offline recovery remains a verification area unless explicitly tested.

37. NOTIFICATIONS

WhatMeal has in-app household notifications.

Notifications may communicate events such as:

member activity
meal creation
meal update
meal deletion
meal completion
provider changes
household activity

Examples may resemble:

Jabez created a meal plan.

or:

A household member completed a meal.

Exact wording should follow the current UI.

38. NOTIFICATION ARCHITECTURE

The preferred architecture separates:

Shared activity
families/{familyId}/activity/{eventId}

This represents household activity.

Private notification receipts
users/{uid}/notificationReceipts/{eventId}

Private read/notification state should not require one user to write another user's private collection.

39. NOTIFICATION PRIVACY

A household member must not be able to write arbitrary private notification records for another user.

Shared household activity should be used for shared events.

Private receipts should be user-scoped.

40. NOTIFICATION REALTIME

In-app notification history should update in real time.

Users should see household activity without manually refreshing.

Notification listeners must respect:

authenticated UID
household membership
account switching
member removal
41. PUSH NOTIFICATIONS

Foreground Firebase Messaging behavior has been implemented/tested to some degree.

Foreground behavior includes:

Firebase Messaging
local notification
Android notification channel
sound

However, physical push delivery while the app is:

backgrounded
terminated

requires backend/cloud functionality that was not deployed because of Spark/free-tier constraints.

Therefore:

Do not assume physical background/terminated push is fully functional.

Do not deploy Cloud Functions or require Blaze unless explicitly approved.

42. NOTIFICATION ROUTING

Notifications may contain route information.

Routing must safely handle:

missing payload
malformed payload
wrong types
cold start
authentication timing
current household scope

GoRouter integration must not assume arbitrary payload types.

43. CONFIRMATION DIALOGS

Important/destructive actions should ask for confirmation.

Examples:

logout
delete saved plan
delete meal
remove household member
leave household
delete household data
remove provider/API configuration
other destructive operations

Typical pattern:

Are you sure you want to continue?

The exact UI should follow the established design.

Do not add confirmations to every trivial action.

44. UI STATES

Every major feature should account for:

loading
success
empty
error
disabled
permission denied
offline/reconnecting
stale/expired state
confirmation
completion

Examples:

Empty

No family members:

Add family members to personalize your meal recommendations.

Loading

AI generation should visibly communicate that generation is in progress.

Error

User-facing errors should be safe and understandable.

Do not expose:

API keys
raw provider response bodies
internal stack traces
sensitive Firebase information
45. ERROR HANDLING

User-facing errors should be actionable and safe.

Avoid exposing raw:

exceptions
HTTP response bodies
API credentials
provider endpoints containing secrets
internal Firebase details

Stage 2 improved redaction, including AI parser output and public provider exception text.

However, a repo-wide audit of every log/exception/notification path is still required before claiming complete redaction.

46. FIREBASE SECURITY

Firestore rules are security-critical.

Requirements include:

UID isolation
household membership authorization
explicit role permissions
ownership protection
invitation protection
schema validation
field allowlists
size/type validation
notification privacy
private data isolation

Do not solve functionality problems by weakening security rules.

47. CRITICAL SECURITY HISTORY

Stage 1 identified two critical security findings:

C01

Authenticated users could potentially:

enumerate families
obtain invitation codes
append themselves without proving invitation

Family ownership fields could also be changed.

C02

Recursive/shared write permission could override role-specific intent.

This could permit:

role escalation
unauthorized writes
view-only writes

These must remain treated as critical until actual approved security architecture and verification prove otherwise.

48. SECURITY RULE DESIGN

The intended security model should be:

Default deny
+
Explicit role permissions
+
Field allowlists
+
Schema validation
+
Canonical membership

Do not use a broad recursive write rule to simplify development.

49. SECURITY TEST MATRIX

Security testing should include:

owner
admin
member
view-only
outsider
guessed family ID
guessed invitation token
expired invitation
reused invitation
concurrent invitation redemption
unauthorized membership
role escalation
ownership modification
field injection
schema violation
cross-household reads
cross-household writes
member removal
permission revocation

If the Firestore emulator/environment cannot run, report verification as blocked.

Never pretend emulator security tests passed.

50. FIREBASE ENVIRONMENT

Known project:

whatmeal-101

Firestore:

Native Firestore
realtime enabled

Billing:

Firebase Spark/free tier

Do not introduce dependencies requiring paid Firebase infrastructure without explicit approval.

51. CLOUD FUNCTIONS CONSTRAINT

Cloud Functions were not deployed because of cost/Spark constraints.

Do not assume Cloud Functions are available.

Do not automatically add a Cloud Function solution for:

notifications
cascading deletion
server-side AI proxy
quota enforcement

unless explicitly approved.

Prefer Spark-compatible client architecture where safe.

52. APP CHECK

Firebase App Check is part of the project.

Historical issue:

debug App Check setup/token was identified
real production attestation configuration remained incomplete

Do not claim production App Check is fully configured without device verification.

Old debug tokens should be revoked/removed when moving to production-safe configuration.

53. BUILD / TEST ENVIRONMENT LIMITATIONS

A significant environment issue was encountered.

Gradle and Firestore emulator startup encountered:

Unable to establish loopback connection

and Java NIO selector startup failures.

The problem occurred under Java 17/21 testing.

Ordinary TCP loopback worked, but:

Selector.open()

failed.

This prevented:

normal Gradle build verification
Firestore emulator verification
some security tests
device/build validation

A recommended diagnostic is to run the Java loopback probe directly from normal PowerShell using the Android Studio JDK.

Do NOT:

disable security products
make broad firewall exclusions
modify network adapters unnecessarily
bypass managed security
weaken security to make tests pass
54. CURRENT TEST HISTORY

Stage 1:

Flutter analyze: passed
Flutter tests: 47 passed
release APK build blocked by Gradle loopback issue

Stage 2:

replacement tests: 5 passed
quota tests: 3 passed
grocery tests: 4 passed
saved-plan stream tests: 2 passed
custom adapter tests: 5 passed
full suite: 66 passed
Flutter analyze: passed
git diff --check: passed

However, this does NOT mean the entire application is fully verified.

Still unverified historically:

live authentication
real Firebase writes
two-device synchronization
real AI provider calls
physical push notifications
offline recovery
complete UI/E2E flows
APK installation
iOS build
complete security emulator suite
full visual/accessibility QA
55. CURRENT AUDIT HISTORY
Stage 1

32 findings were identified:

2 critical
12 high
14 medium
4 low

Stage 1 implemented:

13 fixes
5 partial mitigations

14 findings remained unresolved.

Stage 2

Stage 2 repaired/advanced:

H09 replacement races
M03 grocery initialization
M04 quota reservation
M14 saved-plan realtime synchronization
M07 redaction
M09 regression coverage
M13 custom provider protocol

Critical security issues C01/C02 were intentionally NOT silently changed.

H07/H08 were documented but remained open.

M05 secure credential storage remained a design decision rather than a completed migration.

M10 rules/allowlist design remained pending implementation/verification.

56. IMPORTANT KNOWN FINDINGS

The following historical findings must not be forgotten.

H01

Family repository retained family ID across logout.

Mitigation implemented.

Device verification still required.

H02

Stale async reads/cached plans during account switching.

Guards/resets implemented.

Emulator/device testing still required.

H03

Provider switching retained old credentials/model list.

Fixed.

H04

LlmService could use stale in-memory credentials.

Fixed.

H05

App Check debug setup.

Partially addressed; production attestation remains.

H06

Replacement flows previously omitted dietary restrictions.

Partially addressed; needs validation of all profile/participant/allergen semantics.

H07

Member removal/household deletion could require writes to another user's private documents.

Current rules reject unsafe writes.

Needs safe unlink/archive protocol.

H08

Notification fan-out could attempt writes to private recipient collections and fail.

Shared activity architecture is preferred.

H09

Concurrent meal replacement could create duplicate successors.

Transactional fix implemented.

Real concurrent testing remains required.

H10

AI output validation.

Implemented for structural issues.

Does not guarantee nutritional/allergen correctness.

H11

Startup Firebase errors were swallowed.

Fail-safe startup behavior implemented.

Device testing required.

H12

Android release signing/example app ID and iOS provisioning were not fully verified.

M01

Notification route mismatch/cold-start/auth timing remains an area for testing.

M02

Logout token cleanup improved.

Device testing required.

M03

Grocery initialization improved.

Legacy duplicate scenarios remain.

M04

Gemini quota reservation improved.

Not server-enforced.

M05

Provider secrets not yet guaranteed to use OS-backed secure storage.

M06

Provider settings persistence/session guards improved.

Cross-device listener verification remains.

M07

Raw exception/provider data redaction improved.

Repo-wide audit remains.

M08

Empty member names causing RangeError fixed.

M09

Tests improved but full E2E/widget/device coverage remains incomplete.

M10

Firestore schema/field allowlists remain important.

M11

Family.isOwner previously compared createdBy to itself.

Fixed with UID-aware logic.

M12

regenerateInviteKey was previously a no-op/not fully wired.

M13

Custom provider adapter protocol was previously overstated.

Now explicitly OpenAI-compatible.

M14

Saved-plan nested realtime synchronization improved.

Offline/multi-device verification remains.

57. DATA OWNERSHIP PRINCIPLE

Always distinguish:

Private user data

Examples:

credentials
private settings
private notification receipts
user-specific provider configuration
Household shared data

Examples:

family
pantry
grocery
meal plans
household activity
Authentication data

Owned by Firebase Authentication.

Never duplicate passwords into Firestore.

58. DATA SCOPING

Every repository/service must explicitly consider:

Firebase UID
+
Household ID
+
Role

A query that only checks a document ID is not automatically safe.

Avoid:

"if I know the familyId, I can read it"

Authorization must be enforced by Firestore rules and application logic.

59. UI / FIGMA DESIGN

The user already has an established WhatMeal design.

Do NOT redesign the application without explicit instruction.

The project has existing Figma screens.

Expected approach:

preserve existing design
preserve branding
preserve layout
add missing interactions/states within the established design
do not rebuild the entire app in another design system

Important missing-state categories previously identified include:

login/register states
family CRUD
ingredient CRUD
AI loading
grocery checkboxes
save/delete/reuse plan
errors
empty states
dialogs
confirmation states
60. USE CASE MODEL

The WhatMeal use case model includes household planning.

Primary actor:

Household Planner / User

AI recommendation generation is part of the application workflow.

Important relationships include:

Generate Meal Plan
    <<include>>
Generate AI Recommendations

Generate Grocery List
    <<include>>
AI Recommendations

The exact UML may evolve, but it should remain consistent with the actual product.

61. MAIN END-TO-END WORKFLOW

A complete intended workflow is:

REGISTER / LOGIN
        ↓
CREATE OR JOIN HOUSEHOLD
        ↓
SET UP FAMILY MEMBERS
        ↓
SET DIETARY RESTRICTIONS
        ↓
SET CUISINE PREFERENCE
        ↓
ADD PANTRY INGREDIENTS
        ↓
MANAGE GROCERY LIST
        ↓
GENERATE AI RECOMMENDATIONS
        ↓
GENERATE WEEKLY MEAL PLAN
        ↓
REVIEW MEALS
        ↓
ACCEPT MEAL
        ↓
REPLACE / REGENERATE IF NEEDED
        ↓
SAVE PLAN
        ↓
VIEW SAVED PLAN
        ↓
MARK MEALS COMPLETED / NOT COMPLETED
        ↓
HOUSEHOLD ACTIVITY / NOTIFICATIONS
62. SHARED HOUSEHOLD WORKFLOW

Expected:

OWNER
 ↓
CREATE HOUSEHOLD
 ↓
INVITE MEMBER
 ↓
MEMBER ACCEPTS INVITATION
 ↓
MEMBER JOINS HOUSEHOLD
 ↓
MEMBER SEES SHARED DATA
 ↓
MEMBER MAKES AUTHORIZED CHANGE
 ↓
OWNER SEES CHANGE

Changes should synchronize through the shared household scope.

63. ACCOUNT ISOLATION WORKFLOW

Expected:

ACCOUNT A
 ↓
LOGIN
 ↓
USE APP
 ↓
LOGOUT
 ↓
ACCOUNT B
 ↓
LOGIN
 ↓
USE APP

Account B must never receive Account A's stale state.

64. AI PROVIDER FALLBACK WORKFLOW

Expected:

Gemini
 ↓
configure custom provider
 ↓
custom provider active
 ↓
generate meal
 ↓
remove custom provider
 ↓
Gemini automatically becomes active
 ↓
generate meal again

No stale custom credential should remain active.

65. SAVED PLAN WORKFLOW

Expected:

CREATE PLAN
 ↓
SAVE
 ↓
OPEN SAVED PLAN
 ↓
MODIFY MEAL STATUS
 ↓
REALTIME UPDATE
 ↓
DELETE SAVED PLAN
 ↓
ASSOCIATED STATE CLEANUP
66. MEMBER REVOCATION WORKFLOW

Expected:

MEMBER HAS ACCESS
 ↓
OWNER REMOVES MEMBER
 ↓
MEMBER LISTENER STOPS
 ↓
MEMBER'S HOUSEHOLD DATA IS NO LONGER ACCESSIBLE
 ↓
FUTURE READS FAIL
 ↓
FUTURE WRITES FAIL

Client-side stale cache must not make revoked data appear current.

67. DEVELOPMENT PRINCIPLES

When modifying WhatMeal:

Inspect before changing.
Prefer minimal safe changes.
Preserve existing working functionality.
Do not rewrite entire systems unnecessarily.
Do not redesign the UI without permission.
Do not weaken security.
Do not introduce paid infrastructure without approval.
Do not expose secrets.
Add regression tests for meaningful fixes.
Verify cross-feature behavior.
Distinguish implemented from verified.
Document unresolved limitations.
Never claim success based solely on static code inspection.
Never claim tests passed if the test actually did not execute.
Never silently ignore an existing security finding.
68. CHANGE SAFETY

Before major changes:

inspect git status
inspect current diff
understand affected architecture
identify migration requirements
avoid destructive changes

Do not:

reset user work
delete production data
deploy security rules
deploy Cloud Functions
enable billing
change Firebase project
perform destructive migrations

without explicit approval.

69. MIGRATIONS

Any database migration must be:

backward-aware
scoped
reversible where possible
tested
documented

Do not automatically delete legacy documents just because a new schema exists.

Do not assume all users have the newest client.

70. TESTING PHILOSOPHY

Testing should occur at multiple levels.

Unit

Examples:

parsers
repositories
provider adapters
quota
replacement logic
grocery deduplication
Widget

Examples:

dialogs
loading states
empty states
meal interactions
navigation
Integration

Examples:

Firebase Auth
Firestore
AI
notifications
Security

Examples:

owner
admin
member
view-only
outsider
escalation
invitation abuse
Device

Examples:

actual login
actual Firebase sync
push notifications
APK
background/terminated behavior
offline recovery
71. TEST RESULT INTERPRETATION

A passing test means only that the tested behavior passed.

It does NOT prove:

entire app is complete
all requirements exist
all devices work
production security is correct
Firebase production configuration is correct
notifications work in all lifecycle states
AI providers work against every real endpoint

Always report verification scope.

72. RELEASE READINESS

WhatMeal should not be called release-ready until the important gates are verified.

Minimum release gates include:

authentication
account isolation
household security
invitation security
family CRUD
pantry
grocery
meal generation
meal replacement
saved plans
realtime synchronization
notifications
provider switching
provider fallback
credential security
Firestore rules
Android release build
device installation
core end-to-end workflow
73. KNOWN LIMITATIONS

Unless later verified/fixed, the following should be treated as limitations:

full live authentication verification
live AI provider verification
complete two-device synchronization
complete offline recovery
complete notification lifecycle testing
physical background/terminated push without Cloud Functions
full Firebase security emulator suite
production App Check verification
Android release build due environment loopback issue
iOS build verification on Windows
complete visual/accessibility audit
OS-backed API credential migration
complete provider-by-provider live compatibility testing
74. WHAT COUNTS AS "IMPLEMENTED"

A requirement should be marked:

IMPLEMENTED

only when:

the code exists,
the correct execution path uses it,
it matches the requirement,
authorization/scoping is correct,
important states are handled,
there is sufficient evidence that it works.

If code exists but has not been exercised in the required environment:

UNVERIFIED

may be more appropriate.

If only part works:

PARTIALLY IMPLEMENTED

If it exists but fails:

BROKEN

If it does not exist:

MISSING

If requirements disagree:

CONFLICTING

If a requirement was explicitly superseded:

OBSOLETE

75. CODEX AUDIT INSTRUCTIONS

When Codex is asked to audit WhatMeal, it should:

Step 1

Read this file completely.

Step 2

Inspect the entire repository.

Step 3

Inspect:

Firebase config
Firestore rules
auth
repositories
services
models
screens
routing
AI adapters
notification services
listeners
tests
Step 4

Compare actual implementation against this context.

Step 5

Identify:

implemented
partial
missing
broken
unverified
conflicting
obsolete
Step 6

Repair safe issues automatically.

Step 7

Add regression tests.

Step 8

Run available validation.

Step 9

Update this document if the product requirements or verified implementation changes.

Step 10

Report unresolved issues explicitly.

76. IMPORTANT: DO NOT ASSUME COMPLETENESS

This document is intentionally comprehensive, but it is not permission to assume that every listed feature currently works.

The distinction is:

REQUIREMENT
    ↓
IMPLEMENTATION
    ↓
TEST
    ↓
REAL ENVIRONMENT VERIFICATION

These are separate stages.

For example:

"Push notifications exist"

does not mean:

"Push notifications work while the app is terminated on a physical device."

Similarly:

"Firestore rule exists"

does not mean:

"Firestore security has been verified against all role-escalation cases."
77. PRODUCT NON-GOALS

Do not introduce the following unless explicitly requested:

unnecessary social networking
public meal feeds
unrelated marketplace functionality
paid subscription system
Cloud Functions solely for convenience
custom backend server
custom cryptography
unrelated AI features
arbitrary redesign
unrelated analytics systems
unnecessary third-party services

WhatMeal should remain focused on household meal planning.

78. FINAL PROJECT PRINCIPLE

The goal of WhatMeal is not merely:

"The app compiles."

The goal is:

A secure, synchronized, household-oriented AI meal-planning application whose implemented behavior matches the requirements established for the project.

Every future major development task should consider:

FUNCTIONALITY
+
SECURITY
+
DATA SCOPE
+
REALTIME SYNC
+
ERROR HANDLING
+
UI STATES
+
CONCURRENCY
+
TESTABILITY

before declaring a feature complete.

79. SOURCE / AUTHORITY ORDER

When resolving uncertainty, use this order:

Explicit current user requirement
Approved security architecture/design
Current code behavior
Existing project documentation
Historical audit findings
Older conversation decisions

If a newer explicit requirement conflicts with an older requirement, the newer explicit requirement wins.

Never silently resolve a major conflict.

Report it.

80. FINAL INSTRUCTION TO AI AGENTS

Before changing WhatMeal, ask:

"What existing functionality could this change break?"

Then inspect the relevant dependency chain.

Do not implement isolated fixes that break:

authentication scope
household scope
realtime listeners
AI context
saved plans
notifications
security
account isolation

When uncertain:

inspect more code
inspect tests
inspect Firebase rules
inspect the relevant architecture documentation
identify the uncertainty
avoid guessing

The expected behavior is:

Audit first → understand → implement minimally → test → verify → document.

Never:

Guess → rewrite → claim complete.

END OF WHATMEAL CONTEXT

### One important recommendation

I would save this as:

```text
whatmeal/
├── WHATMEAL_CONTEXT.md
├── README.md
├── audit/
├── lib/
├── android/
├── ios/
└── ...
```
