# WhatMeal instructor Q&A

Twenty-four short, source-grounded answers: **six per presenter**. Study these separately; they do not add time to the ten-minute script. Each member should also know the architecture answer in question1 and the honesty rules at the end.

## Jabez — application structure, identity and manual planning

### 1. What is the overall architecture?

“Flutter pages handle interaction, repositories expose changing application data, and services handle Firebase or AI operations. Models translate stored/request data into typed objects. GoRouter handles routes and authentication redirects. Provider injects some services, while many screens listen directly to ValueNotifier repositories.”

Source: `lib/main.dart:214–220`; `lib/app.dart:8–59`; `lib/core/routing/app_router.dart:29–104`. Do not claim a uniform BLoC/Riverpod architecture.

### 2. Why does signing in not always open Home immediately?

“The router checks both authentication and email verification. An unsigned account goes to login; an authenticated but unverified account goes to the verification page. I've Verified My Email reloads the Firebase user before the app decides whether to open Home.”

Source: `lib/core/routing/app_router.dart:34–56`; `lib/features/auth/pages/verify_email_page.dart:39–98`; `lib/features/auth/data/auth_repository.dart:83–99`.

### 3. Are family profiles the same as household accounts?

“No. A planned-for profile stores a person's age, preferences and restrictions. Household membership connects an authenticated UID to a household and a role. We can plan meals for someone who does not have an app account, but that does not give them permission to read the household.”

Source: `lib/features/profile/models/family_member.dart:3–69`; `lib/features/profile/data/family_member_repository.dart:59–144`; `lib/features/family/models/family_space.dart:1–40`.

### 4. How do you stop a manual plan's blank template meals from being saved as real dishes?

“The manual creator makes authorable slots. Before saving, mealsForSaving omits untouched blank manual slots. A slot with partial content but no dish name is still invalid. The repository then writes the authored meals; opening an editor alone is not persistence.”

Source: `lib/features/meal_plan/pages/meal_plan_page.dart:118–183`; `lib/features/meal_plan/models/saved_meal_plan.dart:365–385`; `lib/features/meal_plan/data/saved_plans_repository.dart:269–321`.

### 5. What determines the calendar date, especially across weeks/months?

“It uses the plan's scheduled start date and each meal's day index, not createdAt. The overview combines eligible saved plans for that day. Month navigation clamps the selected day to a valid day in the target month. The detail route also retains the owning plan path.”

Source: `lib/features/meal_plan/models/calendar_plan_day.dart:7–46`; `lib/features/meal_plan/models/saved_meal_plan.dart:429–464`; `lib/features/meal_plan/pages/meal_plan_calendar_page.dart:39–90`.

### 6. Does Home generate a new recommendation with AI every time it opens?

“No. Home filters saved meals scheduled for today against current participants, recipe content and restrictions, then ranks favorites and preference matches. It shows a loading, empty or retry state when appropriate. AI generation is a separate action on the Meal Plan page.”

Source: `lib/features/home/models/home_meals.dart:20–77`; `lib/features/home/pages/home_page.dart:487–573`.

## Leonard — AI, parsing and saved plans

### 7. Are you using Firebase AI Logic or the Gemini Developer API?

“The adapter supports both. A personal Gemini key uses direct REST; the configured academic credential pool also uses the Developer API directly. Without either, the retained Firebase AI path uses Auth and App Check. We must describe the actual installed configuration rather than calling every request Firebase AI.”

Source: `lib/core/services/ai/adapters/gemini_adapter.dart:43–76,164–193`. Do not reveal the configuration's key values or say every clone receives them.

### 8. What information is included in generation?

“The request includes selected people and ages, meal slots, cuisine, restrictions, preferences, pantry quantities, shopping context and optional budget. The page first requires current loaded inventory and synchronized provider settings. Shopping ingredients are described as not yet available pantry stock.”

Source: `lib/features/meal_plan/data/generation_inventory.dart:22–40`; `lib/core/services/ai/ai_models.dart:64–158`; `lib/core/services/ai/pantry_prompt_context.dart:5–18`.

### 9. How do you handle malformed or incomplete AI output?

“The parser extracts and normalizes supported JSON forms, then validation checks the requested meal slots, title, quantities, ingredients and instructions. Restriction checks run as well. A successful HTTP response alone does not make a valid plan, and these checks are not a food-safety certification.”

Source: `lib/core/services/ai/ai_json_parser.dart:12–80`; `lib/core/services/ai/ai_models.dart:38–59,349–358`; `lib/core/services/llm_service.dart:271–351`.

### 10. If AI succeeded but Firestore failed, must you generate again?

“No. Generation produces an unsaved draft. Explicit Save Plan writes it, and a failure keeps the editor available for a save retry. We do not call an unsaved editor a successful saved plan or discard it just to navigate away.”

Source: `lib/features/meal_plan/pages/meal_plan_page.dart:353–387`; `lib/features/meal_plan/pages/generated_meal_plan_page.dart:51–96,301–445`; `lib/features/meal_plan/widgets/unsaved_plan_guard.dart:24–58`.

### 11. Why do you keep the full plan path as well as a meal ID?

“A meal ID alone may appear in another saved plan. The route carries its exact plan path, and resolution also checks the account session. Ambiguous or stale targets are rejected rather than selecting the first matching ID. Favorites and replacement use that same identity boundary.”

Source: `lib/core/routing/meal_route.dart:19–51`; `lib/features/meal_plan/data/saved_plans_repository.dart:183–193,377–418`.

### 12. Can AI freeze the whole timed demonstration? Is free generation unlimited?

“The progress dialog cannot be cancelled and there is no whole-flow deadline, so we prepare the second phone with a saved fallback. Requests have provider limits and our cooperative default allowance is ten per day. We do not promise unlimited access, independent quotas for several keys, or a refund for every failed request.”

Source: `lib/features/meal_plan/pages/meal_plan_page.dart:285–325`; `lib/core/services/ai/adapters/gemini_adapter.dart:251–299`; `lib/core/services/llm_service.dart:58,271–351`; `lib/core/services/ai_quota_store.dart:10–41`.

## Kyle — pantry, quantities, shopping and lifecycle

### 13. How do you calculate what the user still needs to buy?

“The grocery projection combines ingredient requirements from accepted saved meals, groups compatible names and units, and subtracts usable pantry stock. It retains exact source meal paths. Unparseable amounts are flagged for review, so we do not invent a conversion just to show a number.”

Source: `lib/features/grocery/data/meal_grocery_projection.dart:24–201`; `lib/features/grocery/data/grocery_repository.dart:102–166`.

### 14. Can you combine kilograms, grams, cups and packages automatically?

“Only supported compatible units are converted, such as kilograms to grams or liters to milliliters. The code does not guess a density for volume-to-mass or a package's contents. Incompatible units can remain separate, and unknown amounts display Check recipe quantity.”

Source: `lib/features/grocery/data/meal_grocery_projection.dart:54–127,130–201`.

### 15. What happens when you check a grocery item or complete a meal?

“The grocery checkbox stores a shopping marker or receipt; it does not add pantry inventory. A meal's completion updates its lifecycle after pantry checks; it does not deduct stock. Those are current implementation limits, so we do not present either action as an automatic inventory transfer.”

Source: `lib/features/grocery/data/grocery_repository.dart:343–381`; `lib/features/meal/widgets/meal_ingredients_panel.dart:9–26`; `lib/core/services/meal_workflow_store.dart:10–52`.

### 16. How do you avoid duplicate manual grocery items from two clients?

“Names are normalized for case and whitespace and mapped to deterministic document IDs. A transaction checks before creating the row. Current writers therefore coordinate on the same normalized name. Existing older random-ID duplicates are retained, and manual duplicate quantities are not automatically added together.”

Source: `lib/features/grocery/data/grocery_store.dart:9–89`. Do not call this a migration of all legacy duplicates.

### 17. Does showing an expiration warning mean you send automatic expiry push reminders?

“No. The model computes days remaining from the recorded expiration date, and the pantry screen highlights or filters items within five days. We did not establish a scheduled expiration push producer. We can demonstrate that display without claiming a background notification was sent.”

Source: `lib/features/pantry/models/pantry_item.dart:5–46`; `lib/features/pantry/pages/pantry_page.dart:18–89,490–529`.

### 18. Why not calculate groceries while pantry data is still loading?

“Unknown stock is not zero stock. The repositories expose dependency readiness and errors so the app can wait or offer Retry. Session and scope checks also reject delayed callbacks from a previous account. Treating a failed listener as an empty pantry would create misleading shopping requirements.”

Source: `lib/features/grocery/data/grocery_repository.dart:102–129,188–298`; `lib/features/pantry/data/pantry_repository.dart:56–129`.

## Jobert — membership, security, sharing and notifications

### 19. How does an invitation grant household access safely?

“It is an expiring, single-use token. Joining uses a transaction to consume the invitation and create the canonical member record plus account membership index together. Later access depends on stored membership and role rules, not on a client claiming a household ID or owner role.”

Source: `lib/core/services/family_service.dart:37–46,93–170`; `firestore.rules:67–177`.

### 20. What is the difference between Firebase Auth, App Check and Firestore rules?

“Auth identifies the signed-in user. App Check attests the app making protected requests. Firestore rules decide what that user may read or write based on UID, stored membership, role and schema. Passing one layer is not permission to ignore the other layers.”

Source: `lib/main.dart:148–160`; `lib/features/auth/data/auth_repository.dart:113–175`; `firestore.rules:207–241,352–401`.

### 21. Does the second phone read the owner's private documents?

“Authorized household accounts subscribe to shared collections under families, while personal collections stay under each user's UID. Joining switches the active scope; it does not copy all personal records. Listener cleanup and version checks protect account switching. We call synchronization verified only when we actually observe the second phone update.”

Source: `lib/features/family/data/family_repository.dart:36–72,145–238`; `lib/features/pantry/data/pantry_repository.dart:62–129`; `lib/features/meal_plan/data/saved_plans_repository.dart:86–181`.

### 22. How can two members have different unread states for one event?

“The household event is stored once. Each account has its own receipt document under users. Opening the alert updates that user's receipt, so another member's unread state is not overwritten. Pantry updates exclude the actor and new members do not receive every event from before they joined.”

Source: `lib/core/services/household_activity_store.dart:50–57,78–174`; `lib/core/services/notification_service.dart:510–555`.

### 23. Are these notifications real push messages when the app is closed?

“The demonstrated history is an in-app Firestore activity and receipt feed. FCM/background routing code also exists, but that does not prove trusted sending or closed-app delivery. We are not claiming native push passed on two physical phones or that Cloud Functions were deployed.”

Source: `lib/core/services/notification_service.dart:243–395`; `lib/main.dart:31–34,230–299`; `lib/features/notifications/pages/notifications_page.dart:18–45`.

### 24. Is this prototype production-ready, and what is the unresolved security issue?

“We are presenting an academic prototype with clear limits. The configured APK's shared AI credentials are extractable, and an exposed historical App Check debug credential has not been confirmed revoked. The owner accepted that Git-history risk for publication. Removing debug-only code did not revoke it, and we must not reveal the value.”

Source/evidence: `audit/final/ACADEMIC_RELEASE_20261026.md`; current release provider selection in `lib/main.dart:157–160`; the explicit owner decision recorded in the source commit message. Do not claim this is a completed security remediation.

## Answers any member can safely use

- **If asked for a result you did not test:** “That path is implemented, but we have not verified that exact environment. Here is the code and our recorded evidence.”
- **If live AI fails:** “This request did not complete successfully. We are switching to a previously saved plan, not presenting it as a new AI result.”
- **If asked to show a credential:** “We can show the provider configuration flow and relevant code, but we will not display private keys, invitation secrets or debug tokens.”
- **If asked for a code detail you cannot recall:** Open FEATURE_CODE_INDEX.md, locate the callback and follow the repository/service chain. Do not invent a method or claim a generic Flutter pattern that the app does not use.
- **If asked about verification:** Separate automated tests, Firebase emulator cases, the bounded host live-AI proof, prior Android-emulator runs and actual user-observed phone results. Only the last category establishes what happened on those physical phones.
