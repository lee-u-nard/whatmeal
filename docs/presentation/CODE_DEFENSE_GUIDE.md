# WhatMeal code-defense guide

Prepared from the current source on **October 29, 2026**. Paths are relative to the repository root; line ranges refer to this inspected version and may move after edits. These are explanations to study, not additional speech outside the ten-minute script.

No runtime source, Firebase settings, Git index, APK or phone was changed for this task. No new automated, live-provider or physical-device tests were run. Use the evidence table in DEMO_PREPARATION_CHECKLIST.md when discussing verification.

## Architecture answer every presenter should know

> “WhatMeal separates Flutter screens from repositories and services. GoRouter manages navigation and authentication redirects. Repositories listen to Firebase and expose state through ChangeNotifier or ValueNotifier, so widgets rebuild when data changes. Models translate stored data into Dart objects. AI requests pass through a provider adapter, parser and validator, and the user explicitly saves the resulting plan.”

```text
Tap / form input
  → Page callback and validation
  → Repository or service
  → Firebase Auth / Firestore, or an AI adapter and HTTP/SDK call
  → Model parsing and validation
  → ValueNotifier / ChangeNotifier notification
  → ValueListenableBuilder / router / widget rebuild
```

The architecture is not uniformly “Provider does everything.” `lib/main.dart:214–220` injects services and a `ChangeNotifierProvider<MealPlanRepository>`; many active screens use singleton `ValueNotifier` repositories directly. Local form state uses `setState`. `lib/app.dart:8–59` owns the router; `lib/core/routing/app_router.dart:29–178` defines auth redirects and the five indexed-stack branches. Firestore snapshot listeners are not the same as polling or sending push notifications.

### Shared data map

| Purpose | Confirmed path |
|---|---|
| Account profile | `users/{uid}` |
| Planned-for people | `users/{uid}/familyMembers/{profileId}` or `families/{familyId}/familyMembers/{profileId}` |
| Pantry | `users/{uid}/pantryItems/{itemId}` or `families/{familyId}/pantryItems/{itemId}` |
| Grocery rows | `{scope}/{id}/groceryLists/{listId}/items/{itemId}`, where scope is `users` or `families` |
| Plan and recipes | `{scope}/{id}/mealPlans/{planId}` and its `meals/{mealId}` subcollection |
| Canonical household membership | `families/{familyId}/members/{uid}` and `membershipIndex/{uid}` |
| Household invitation | `householdInvitations/{token}`; never show an actual token in documentation |
| Shared activity | `families/{familyId}/activity/{eventId}` |
| Per-account shared read state | `users/{uid}/notificationReceipts/household:{familyId}:{eventId}` |
| Personal notifications | `users/{uid}/notifications/{notificationId}` |
| AI selection/credentials | `users/{uid}/secrets/llmConfig`; owner-scoped storage is not an OS secure-key vault |
| Cooperative app quota | `users/{uid}/usageCounters/daily` |

## Jabez: account context, manual planning and Home

### J1. Authentication and navigation

- **Files/symbols:** `lib/features/auth/pages/login_page.dart:27–59,239–287`, `_LoginPageState._handleLogin`; `lib/features/auth/data/auth_repository.dart:83–175,198–254,326–371`, `AuthRepository.login/register/reloadUser`; `lib/features/auth/pages/verify_email_page.dart:39–98,194–257`, `_checkVerification/_resendVerificationEmail`; `lib/core/routing/app_router.dart:29–104`, `createAppRouter`; `lib/features/auth/models/user_model.dart:1–35`, `UserModel`.
- **Trigger/flow:** **Sign In** validates form → `login` → Firebase Auth sign-in → merges account metadata into `users/{uid}`. **Create Account** checks form/terms → Auth account creation → verification attempt/profile write. Router redirects unsigned users to login and unverified users to verification.
- **Validation/data:** Auth identifies the account by UID, not a typed household name. Login preserves an existing edited display name. Passwords go to Firebase Auth, never to the Firestore profile document.
- **Loading/failure:** Login/register disable their buttons while awaiting. Error codes map to safe messages. Verification can require a resend; registration success does not prove email delivery. Auth profile snapshot callbacks check session/UID before applying state.
- **Say aloud, about 20 seconds:** “The login page calls our authentication repository. Firebase Auth returns the account identity, and the repository synchronizes profile metadata. GoRouter listens to that repository and sends an unsigned user to login or an unverified user to email verification. The screen does not grant its own database permission.”
- **Likely question:** Why not just hide protected tabs? **Answer:** Tabs are a UI concern; the router gates navigation and Firestore rules separately authorize data access.

### J2. Planned-for profiles, preferences and restrictions

- **Files/symbols:** `lib/features/profile/pages/profile_page.dart:20–94,325–346,466–483`, `ProfilePage._openAddMemberSheet/_openEditMemberSheet`; `lib/features/profile/widgets/add_edit_family_member_sheet.dart:118–165,205–458`, `_AddEditFamilyMemberSheetState._submit`; `lib/features/profile/data/family_member_repository.dart:59–144`, `FamilyMemberRepository.addMember/updateMember`; `lib/features/profile/models/family_member.dart:3–69`, `FamilyMember`.
- **Trigger/flow:** **Profile → Add** or **Member actions → Edit Profile** → sheet validates → constructs model → awaited repository write → Firestore snapshot → profile/Home rebuild.
- **Validation/data:** Name is required and bounded; age is constrained to0–130. Preferences and restrictions are stored with the planned-for person in the current personal/household `familyMembers` collection. This person does not automatically receive an Auth account or household permission.
- **Loading/failure:** Sheet prevents duplicate submission and keeps input on failed save. The repository exposes loading/error/retry. Important limitation: the Profile member list does not consume all those loading/error fields; Home recommendations does. Do not promise perfect recovery on every profile screen.
- **Say aloud:** “These profiles describe the people eating, not the accounts signing in. The form validates the name and age, then saves preferences and restrictions through the profile repository. The active workspace determines whether that record is personal or shared. AI and Home recommendations read this context.”
- **Question:** Does adding a child profile invite that child? **Answer:** No. Planned-for profiles and authenticated household members are separate collections and responsibilities.

### J3. Manual meal-plan creation and explicit saving

- **Files/symbols:** `lib/features/meal_plan/pages/meal_plan_page.dart:118–183,517–644,1044–1072`, `_MealPlanPageState._createCustomMealPlan`; `lib/features/meal_plan/pages/generated_meal_plan_page.dart:51–96,301–445,473–630`, `_saveDraft/_showSavePlanDialog/_showEditMealDialog`; `lib/features/meal_plan/models/saved_meal_plan.dart:365–385`, `GeneratedPlanDraft.mealsForSaving`; `lib/features/meal_plan/data/saved_plans_repository.dart:269–321`, `SavedPlansRepository.savePlan`; `lib/features/meal_plan/models/meal_plan.dart:3–80`, `MealPlan`.
- **Trigger/flow:** **Create Own Plan → Create Custom Meal Plan** validates people/types → creates blank local template slots with the selected start date → editor. **Edit Dish → Save Changes** updates a local unsaved meal. **Save Plan** creates the plan/meal documents in an awaited batch.
- **Validation/data:** Untouched blank manual slots are omitted by `mealsForSaving`. A partially entered unnamed meal is invalid. The repository selects the current authorized household path, or the user's personal path when there is no household. It does not silently offer a private-vs-shared save toggle.
- **Loading/failure:** A save is not considered confirmed until the repository finishes; the editor retains a failed draft. **Back** can offer **Keep editing / Discard / Save Plan**. Do not discard a result to hide failure.
- **Say aloud:** “Manual planning creates a draft without an AI call. We edit an actual dish, and untouched blank slots are left out of the saved meal list. Saving writes the plan metadata and its meals through the repository. Until that write succeeds, the editor is only an unsaved draft.”
- **Question:** Why did empty template slots once prevent saving? **Answer:** Template placeholders must not be treated as authored recipes. The current save selection omits untouched slots but still rejects partially entered meals without names.

### J4. Calendar, dates and status shortcuts

- **Files/symbols:** `lib/features/meal_plan/pages/meal_plan_calendar_page.dart:39–90,98–188,232–267`, `_MealPlanCalendarPageState._select/_moveMonth`; `lib/features/meal_plan/models/calendar_plan_day.dart:7–46`, `calendarPlansForDay/mealCalendarMonth`; `lib/features/meal_plan/models/saved_meal_plan.dart:429–464`, `SavedMealPlan.dateForMeal/activeMeals`; `lib/core/routing/meal_route.dart:3–24`, `mealOverviewRoute/mealCalendarRoute/mealRoute`; `lib/features/home/pages/home_page.dart:252–320,579–589`, `_weekStat`.
- **Trigger/flow:** **Home → Calendar**, date tap, month arrows → selected/month state → filters current saved plans by scheduled day → opens plan or meal with its identity. **Pending / Accepted / Done / Favorites** opens filtered history for the displayed week.
- **Validation/data:** Meal date derives from the plan's start date plus meal day index. Creation timestamp is not the calendar date. Multiple plans can contribute meals to one day; replaced predecessors are excluded from active views. Month movement clamps a selected day that does not exist in the destination month.
- **Loading/failure:** Saved-plan listener state controls loading and **Retry Calendar**. Undated plans receive an explicit notice. Session checks reject navigation based on an old account snapshot.
- **Say aloud:** “The calendar displays saved plans on their scheduled dates. It calculates each meal's date from the plan start date and day index, and it can show overlapping plans. Month navigation keeps a valid selected day. Opening a meal carries its plan path, so we do not guess which saved plan owns it.”
- **Question:** Are Sunday and Monday indexes the same as Dart weekday values? **Answer:** No; `WeekCalendar.dayIndexOf` converts Dart's weekday to a Monday-based zero index. The stored plan's actual start date still determines its meal dates.

### J5. Home recommendations and meal-image behavior

- **Files/symbols:** `lib/features/home/models/home_meals.dart:9–77`, `matchesMealFilter/homeRecommendations`; `lib/features/home/pages/home_page.dart:487–573`, Home recommendation builder; `lib/core/services/unsplash_service.dart:76–150,231–270,311–380`, `UnsplashService.validImageUrl/fetchMealImage/dishMatches/_fetchMealDb/_fetchCommons`; `lib/features/meal/widgets/meal_network_image.dart:32–143`, `_MealNetworkImageState._resolve`.
- **Trigger/flow:** Home observes saved plans and planned-for profiles → filters today's pending/accepted recipes → validates restrictions and ranks favorites/preferences → displays up to four. Meal image widget resolves using the actual dish name, not an arbitrary food seed.
- **Validation/data:** Recommendations are local filtering/ranking of authorized saved recipes, not an automatic AI generation. Unresolved participants, missing ingredients, wrong dates and disallowed restrictions exclude a meal. Images can use TheMealDB, Commons and optional configured Unsplash, with title/URL checks and caching.
- **Loading/failure:** Recommendation feeds have spinner, empty state and **Retry Recommendations**. Photo misses/failures use the intentional fallback, with bounded retry/cache behavior. Text matching cannot prove every image's visual correctness or every dietary synonym.
- **Say aloud:** “Home recommends from meals already saved for today. It checks current participants and restrictions, then prioritizes favorites and matching preferences. This avoids an AI request whenever Home rebuilds. Photos are resolved separately by dish identity, and a missing photo does not prevent the recipe from opening.”
- **Question:** Is Recommended for Today a machine-learning recommender? **Answer:** The current Home ranking is rule-based. The separate generation feature calls an external AI provider.

## Leonard: AI and saved-plan integrity

### L1. Provider/model selection and the actual default route

- **Files/symbols:** `lib/features/ai_settings/pages/ai_settings_page.dart:309–368,485–584,790`, `AiSettingsPage`; `lib/features/ai_settings/data/ai_provider_repository.dart:96–113,166–223,268–322,493–519`, `AiProviderRepository.generationReadinessError/selectProvider/updateModel/removeKey`; `lib/core/services/llm_service.dart:128–179`, `LlmService.getLlmConfig/saveLlmConfig`; `lib/core/services/ai/ai_provider_factory.dart:15–72`, `AiProviderFactory.create/validate`; `lib/core/services/ai/adapters/gemini_adapter.dart:43–76,164–193`, `GeminiAdapter.usesFirebaseAi/_generate`; `lib/core/services/ai/model_registry.dart:45–47`, default model constant.
- **Trigger/flow:** Provider/model selection updates the settings notifier → serialized persisted configuration → generation rereads configuration → validates model/protocol → constructs adapter.
- **Validation/data:** Personal Gemini key takes priority, then the configured academic pool uses direct Gemini Developer API. With neither, the retained Firebase AI Logic path uses Auth/App Check. Config lives at `users/{uid}/secrets/llmConfig`; only the owner should read it under rules. A secret-free clone does not receive the private pool.
- **Loading/failure:** Signed-out, pending-write or unsynchronized settings block generation. Removing credentials restores default behavior rather than requiring a personal key. Key storage is not an OS secure vault; APK-shipped shared credentials are extractable.
- **Say aloud:** “The selected provider and model are persisted per account and validated before a request. In this configured prototype, default Gemini can use the direct Developer API. A personal key overrides it, while the Firebase AI route remains available without the configured pool. We report which provider and model actually answered.”
- **Question:** Is generation guaranteed free forever? **Answer:** No. Provider access and quota apply; the app's default configuration does not remove those limits.

### L2. Context, inventory readiness and request quota

- **Files/symbols:** `lib/features/meal_plan/pages/meal_plan_page.dart:186–351`, `_generateMealPlan`; `lib/features/meal_plan/data/generation_inventory.dart:22–40`, `GenerationInventory.capture`; `lib/core/services/ai/pantry_prompt_context.dart:5–18`, `pantryPromptContext`; `lib/core/services/llm_service.dart:58,271–351`, `kDailyQuotaLimit/LlmService.generateMealPlan`; `lib/core/services/ai_quota_store.dart:10–41`, `AiQuotaStore`.
- **Trigger/flow:** **Generate AI Meal Plan** checks editing role, selected members/types/cuisine, UID and workspace → captures loaded pantry/grocery snapshots → reads provider configuration → reserves applicable quota → calls adapter.
- **Validation/data:** Prompt includes recorded member names/ages, restrictions, preferences, cuisine, budget, meal types and inventory quantities. Grocery shopping is described as not yet available stock. Used/needed/expired pantry stock is excluded. The default cooperative quota is10 per account/day; failures after reservation can still consume a reservation.
- **Loading/failure:** Unsynchronized inventory stops before the provider request, rather than pretending the pantry is empty. The progress dialog is non-dismissible. No whole-operation timeout covers all preliminary database work.
- **Say aloud:** “Before generating, the page captures the right household's loaded inventory and selected people. It passes actual quantities and restrictions into the request. The service reserves its applicable daily request allowance before dispatch, which reduces duplicate spending. A failed or ambiguous request is not automatically refunded.”
- **Question:** Is this daily counter strong server-side abuse protection? **Answer:** No. It is a cooperative app limit; a client-owned counter and APK-shipped credentials are not a secure public anti-abuse architecture.

### L3. Adapter request, JSON parsing and safe failure

- **Files/symbols:** `lib/core/services/ai/adapters/gemini_adapter.dart:108–119,149–193,251–299`, `GeminiAdapter.generateMealPlan/_withBundledKey/_generate`; `lib/core/services/ai/ai_models.dart:38–158,349–358`, `AiMealPlanRequest.validateMeals/buildPrompt`, `AiMealResponse.validateRecipe`; `lib/core/services/ai/ai_json_parser.dart:12–80`, `AiJsonParser.parseMealList`; `lib/core/services/ai/bundled_key_pool.dart:37–53`, `BundledKeyPool.requestKeys/canTryNext`; `lib/core/services/ai/generation_failure.dart:303–304`, timeout message.
- **Trigger/flow:** Adapter builds selected-model request → REST or retained SDK route → extracts text → parser normalizes supported JSON wrappers → validates slot count/types/days, quantities, recipe content and restrictions → service returns meals and provider/model metadata.
- **Validation/data:** Malformed or incomplete recipes do not become successful plans merely because HTTP returned200. The configured pool preserves the selected model and makes bounded credential attempts. Only credential/permission/rate-limit cases qualify to try another credential; network, timeout and malformed output do not.
- **Loading/failure:** Provider HTTP generation has a90-second per-request timeout; this is not a full-screen deadline. Failure maps to sanitized **Generation failed** actions, not a raw key-containing exception. Custom-provider fallback is reported rather than silently claimed as the originally selected provider.
- **Say aloud:** “An adapter handles the provider's request and response format. Our parser then extracts meal JSON, but parsing alone is not enough: validation checks the requested slots and required recipe fields. Errors are classified before display. Retrying is bounded and preserves the model, so we do not secretly claim another model generated the result.”
- **Question:** Does valid JSON mean an allergy-safe recipe? **Answer:** No. Structural and ingredient-name checks reduce invalid output, but they are not a medical, cross-contamination or nutritional certification.

### L4. Saving, reopening and exact meal identity

- **Files/symbols:** `lib/features/meal_plan/pages/meal_plan_page.dart:353–412`, draft navigation; `lib/features/meal_plan/pages/generated_meal_plan_page.dart:51–96,301–445`, `_ensurePersisted/_saveDraft/_showSavePlanDialog`; `lib/features/meal_plan/data/saved_plans_repository.dart:86–193,269–321`, `SavedPlansRepository.savePlan/_planRef`; `lib/features/meal_plan/data/saved_plan_stream.dart:7–81`, `watchSavedPlans`; `lib/core/routing/meal_route.dart:19–51`, `mealRoute/resolveSavedMeal`.
- **Trigger/flow:** Generation success constructs `GeneratedPlanDraft` → user **Save Plan** → awaited metadata/recipe batch → saved path assigned → **Saved → Load Plan** reads streamed data and reopens the same plan.
- **Validation/data:** Plan lives under current `families/{familyId}/mealPlans/{planId}`, otherwise personal `users/{uid}/mealPlans/{planId}`; meals are nested. Reopening/favorites/replacements carry full `sourcePath` plus meal ID. Session checks reject stale account results and ambiguous IDs.
- **Loading/failure:** Parent metadata and nested meals each have listeners, so child edits can refresh independently. Save failures retain the draft and must not report success. `persistGeneratedPlanDraft` is a defined helper, not the current live UI path; do not describe generation as automatic persistence.
- **Say aloud:** “Generation creates a draft, and saving is a separate database operation. A batch writes plan metadata and nested recipes, then the editor stores the confirmed document path. Reopening uses that path with the meal ID and current session, preventing a same-ID meal in another plan from being selected accidentally.”
- **Question:** Can Firestore failure mean AI also failed? **Answer:** They are separate stages. A successfully generated draft can remain available for a save retry without another AI request.

### L5. Favorites, history, reuse and replacement

- **Files/symbols:** `lib/features/meal/pages/meal_detail_page.dart:245–394,434–468`, `_replaceWithAi` and favorite callback; `lib/features/meal_plan/data/saved_plans_repository.dart:377–418`, `toggleFavorite/replaceMeal`; `lib/core/services/meal_replacement_store.dart:17–90`, `MealReplacementStore.replace`; `lib/features/meal_plan/models/saved_meal_plan.dart:290–346,463–464`, reuse transformation and `activeMeals`; `lib/features/meal_plan/pages/meal_history_page.dart:24–69`, `MealHistoryPage` filtering.
- **Trigger/flow:** Heart writes `isFavorite` on exact recipe. History derives filtered saved active meals. **Reuse** creates a new unsaved draft with new IDs/pending states. **Replace with AI** confirms, requests a successor and transacts the replacement links.
- **Validation/data:** Replacement keeps the predecessor, marks it replaced, links it to one successor in the same slot, and hides it from active views. This is not deleting an unrelated plan. Reuse starts a new current-Monday copy; it is not the same as reopening a saved plan with its original date.
- **Loading/failure:** Replacement shows **Asking AI…** and preserves the original if the request/write fails. The transactional store protects against concurrent duplicate successors. Do not demonstrate another slow replacement request inside the timed script.
- **Say aloud:** “Favorites are persisted recipe fields, while history is a view over saved meal states. Reuse makes a new draft and new identities. Replacement is different: it retains the old record and links a single new meal in the same slot through a transaction, which prevents competing replacements from producing two active successors.”
- **Question:** Why not simply overwrite the old meal? **Answer:** Preserving/linking the predecessor supports consistent history, identity and concurrent replacement handling.

## Kyle: stock, shopping and meal states

### K1. Accepted, completed and not-completed states

- **Files/symbols:** `lib/features/meal/models/meal.dart:17–60`, `MealStatus`; `lib/features/meal/pages/meal_detail_page.dart:112–188,984–1132`, `_updateStatus` and action controls; `lib/features/meal/widgets/meal_ingredients_panel.dart:9–26`, `mealCookingProblem`; `lib/features/meal_plan/data/saved_plans_repository.dart:352–374`, `updateMealStatus`; `lib/core/services/meal_workflow_store.dart:10–52`, `MealWorkflowStore.setStatus`.
- **Trigger/flow:** **Accept Meal / Mark Completed / Not Completed** → confirmation → current scope/permission/inventory checks → status transaction → plan listener refresh.
- **Validation/data:** Completion checks pantry readiness, ingredient presence and supported quantity coverage. The transaction updates recipe state/accepted compatibility field, plan timestamp and relevant household activity. It does **not** decrement pantry inventory.
- **Loading/failure:** Confirmation precedes the write, and the transaction treats an already-current status as a no-op. The detail-page callback has no dedicated in-flight/busy guard; tap once and await the result. Its pantry check runs after confirmation and can reject completion with feedback. Stale sessions cannot update a newly switched account's meal. Do not claim that missing stock necessarily disables the button beforehand.
- **Say aloud:** “These labels represent persisted meal states. The details page confirms important changes, checks the current account and pantry, then asks the repository to update through a transaction. Completion records that state, but the current implementation does not automatically consume or deduct inventory.”
- **Question:** Is a checked grocery item the same as a completed meal? **Answer:** No. Shopping markers, pantry stock and meal lifecycle are separate records.

### K2. Pantry CRUD, expiry and same-record editing

- **Files/symbols:** `lib/core/widgets/app_shell.dart:29–50`, `AppShell._fabForTab`; `lib/features/pantry/widgets/add_pantry_item_sheet.dart:68–118,146–237`, `AddPantryItemSheet`; `lib/features/pantry/pages/pantry_page.dart:18–179,490–566`, `_editItem/_confirmDeleteItem`; `lib/features/pantry/data/pantry_repository.dart:56–167`, `PantryRepository.addItem/updateItem/retry`; `lib/features/pantry/data/pantry_store.dart:8–48`, `PantryStore.write`; `lib/features/pantry/models/pantry_item.dart:5–46`, `PantryItem/PantryStatus`.
- **Trigger/flow:** **Pantry → Add pantry item → Add Ingredient → Add to Pantry**, or **Item options → Edit Item → Save Changes** → awaited repository/store → current scoped pantry document → snapshot refresh.
- **Validation/data:** Name, quantity text and expiration date are required by the form. Editing updates the same item ID even when category changes. `expiresInDays` is computed from the stored date; the screen highlights/filter-matches items at five days or less.
- **Loading/failure:** Save-in-progress blocks duplicate form submission; failed save keeps input. Delete requires confirmation. Displaying an expiration warning does not prove a scheduled notification service exists.
- **Say aloud:** “A pantry item is one stored record with a name, quantity text, category and expiration date. Editing keeps its identity rather than making a duplicate in another category. The page listens for changes and calculates the expiration warning from the recorded date. A failed save stays visible for correction.”
- **Question:** Does the quantity field guarantee every unit can be calculated? **Answer:** No. It stores text; the grocery projection separately parses supported units and shows uncertainty for unsupported amounts.

### K3. Pantry-aware grocery requirements and provenance

- **Files/symbols:** `lib/features/grocery/data/meal_grocery_projection.dart:24–50,54–201`, `MealGroceryRequirement.toItem`, `IngredientQuantity`, `MealGroceryProjection.calculate`; `lib/features/grocery/data/grocery_repository.dart:102–166`, dependency readiness and `_publish`; `lib/features/meal_plan/models/saved_meal_plan.dart:463–464`, `activeMeals`; `lib/core/utils/ingredient_matcher.dart`, `IngredientMatcher`.
- **Trigger/flow:** Current saved accepted meals plus loaded pantry → normalize ingredient/compatible unit → sum requirements → subtract usable stock → merge with persisted grocery rows/receipts → notify UI.
- **Validation/data:** It tracks full source meal paths, not a global dish name. Expired, Used and Needed pantry items do not supply stock. Supported conversions include kilograms/grams and liters/milliliters; it does not guess mass-to-volume or package conversions. Different units can remain separate requirements.
- **Loading/failure:** A missing/loading/error dependency must not be treated as an empty pantry and create misleading shortages. Unknown quantities show **Check recipe quantity**. Removing one meal must retain quantities still required by other source meals.
- **Say aloud:** “The grocery list is partly derived from accepted saved meals. It combines compatible ingredient requirements, keeps their source meal paths and subtracts usable pantry quantities. This lets it preserve another meal's requirement when one meal changes. When a quantity cannot be safely interpreted, the app asks us to check the recipe.”
- **Question:** Why include the source plan path? **Answer:** Meal IDs can repeat across plans; provenance must identify the exact stored recipe and its surviving requirement.

### K4. Manual groceries, purchase markers and duplicate prevention

- **Files/symbols:** `lib/features/grocery/widgets/grocery_item_editor.dart:88–169`, `GroceryItemEditor`; `lib/features/grocery/data/grocery_store.dart:9–89`, `GroceryStore.normalizedName/updateManual/initialize/addUnique`; `lib/features/grocery/data/grocery_repository.dart:304–381,479–525`, `cycleStatus/setPurchased`; `lib/features/grocery/pages/grocery_page.dart:103–142,400–489`, `_shareGroceryList` and tile controls.
- **Trigger/flow:** Plus → **Add Grocery Item → Add to List** → normalized-name transaction. Checkbox → purchase marker/receipt write → UI Used/checked state. **Share List** copies text to clipboard; it does not send a message or invite an account.
- **Validation/data:** New manual rows use deterministic name IDs and a transaction. Case/whitespace duplicates are prevented for current writers, but quantities are not automatically summed for duplicate manual names. Older random-ID duplicates are retained. Meal-derived edits/deletes must be done through their source meals.
- **Loading/failure:** Duplicate/persistence errors are surfaced; scope changes reject stale writes. Purchase receipts consider source paths/covered quantity. **Clear Used** removes eligible checked manual rows, not all meal provenance.
- **Say aloud:** “Manual shopping items are normalized and added transactionally so two current clients do not create the same normalized name twice. Checking a row stores a shopping marker. It does not add pantry stock. Meal-derived rows have source links and receipts, so we do not casually delete requirements that another recipe still needs.”
- **Question:** Does Share List synchronize accounts? **Answer:** No; it copies text. Household synchronization comes from shared Firestore paths and listeners.

### K5. Feed readiness, retry and failure recovery

- **Files/symbols:** `lib/features/pantry/data/pantry_repository.dart:56–129`, `retry/_resetListener/_listenToItems`; `lib/features/grocery/data/grocery_repository.dart:102–129,188–298`, `retry/_resetListener/_initializeActiveList`; `lib/features/meal_plan/data/saved_plan_stream.dart:7–81`, `watchSavedPlans`; `lib/core/widgets/listener_recovery_notice.dart`, `ListenerRecoveryNotice`.
- **Trigger/flow:** Auth/household changes reset scoped listeners; stream events update notifier state; terminal errors expose recovery; **Retry** creates new subscriptions for the current scope.
- **Validation/data:** Session/scope epochs prevent a delayed callback from populating the next account's screen. Loading/error is different from an authoritative empty collection. Grocery initialization reuses an existing latest list or transactionally creates `default` when necessary.
- **Loading/failure:** Do not claim unrestricted offline operation. Cached reads may remain available, but authentication, AI, synchronized writes and definitive recovery depend on the actual service state. Retry does not bypass a permission denial.
- **Say aloud:** “A listener can fail permanently, so the repository exposes an error and can attach a fresh stream when Retry is requested. It also records the account or workspace version. That prevents a delayed operation from a previous account from becoming the current account's data, and it prevents us from calculating against an inventory that has not loaded.”
- **Question:** Why not convert every listener error into an empty list? **Answer:** That would confuse denied/offline data with real absence and could create incorrect grocery or user-visible results.

## Jobert: household boundaries and notifications

### O1. Invitations and canonical membership

- **Files/symbols:** `lib/features/profile/pages/profile_page.dart:277–294`, Family Sharing entry; `lib/features/family/pages/family_space_page.dart:137–148,700–805`, `_issueInvitation`; `lib/features/family/widgets/household_access_sheet.dart:129–205`, `HouseholdAccessSheet`; `lib/features/family/data/family_repository.dart:262–288,290–326`, `createSpace/joinSpaceWithKey/revokeToken`; `lib/core/services/family_service.dart:37–46,60–170`, `FamilyService.createFamily/createInvitation/validateToken/joinFamily/revokeInvitation`.
- **Trigger/flow:** Authorized owner/admin creates a random invitation → invitation document → second authenticated account submits **Join Family Space** → transaction validates and consumes invitation while creating membership and index.
- **Validation/data:** Default invitation is single use, case-sensitive,32 characters and expires after48 hours. Canonical membership is `families/{familyId}/members/{uid}`, located through `membershipIndex/{uid}`; knowing a household ID is insufficient to self-join.
- **Loading/failure:** Repository `_perform` surfaces failure; expired/revoked/used invitations are rejected. An already-member account cannot simply join another household through this form. Do not remove a working membership during the timed demo.
- **Say aloud:** “The invitation is a temporary authorization to join, not the household's public ID. A transaction consumes it and creates the member record and account index together. Subsequent access comes from stored membership and role checks. We pre-joined the presentation accounts to avoid transferring a secret invitation while the timer is running.”
- **Question:** Can an outsider add their UID to a family document? **Answer:** The coordinated membership/rules design rejects direct self-joining; the invitation transaction and allowed schema must agree.

### O2. Roles, departure and archival behavior

- **Files/symbols:** `lib/features/family/models/family_space.dart:1–40`, `FamilyRole/FamilyRoleX`; `lib/core/services/family_service.dart:172–236`, `leaveFamily/removeMember/updateMemberRole/deleteFamily/offerOwnership/acceptOwnership`; `lib/features/family/data/family_repository.dart:335–408`, role/removal/departure operations; `firestore.rules:10–16,67–177,207–241`, stored membership, coordinated changes and data-scope authorization.
- **Trigger/flow:** Role-sensitive controls → repository → constrained service write/batch/transaction → rules validate actual stored authority and coordinated data → listeners update.
- **Validation/data:** Owner/admin/member can perform permitted food writes; View Only cannot. Owner/admin management is further constrained by backend role rules. Owner changes require an offered and accepted transfer, not assigning a role string `owner`. Removing/leaving deletes the membership/index pair. `deleteFamily` archives household state and retains nested data; it is not recursive deletion.
- **Loading/failure:** Confirmation dialogs protect significant actions; errors do not grant extra permission. Legacy/inaccessible households can have special notices/recovery, not a permission bypass. Do not exercise destructive/member actions live for the ten-minute talk.
- **Say aloud:** “Roles come from stored membership. The UI reflects permissions, but the security rules still decide whether a write is allowed. Ownership uses a separate transfer flow. Leaving removes the membership relationship, while the household removal operation is archival, retaining nested data instead of pretending a client can safely erase everyone's records.”
- **Question:** Does App Check replace household rules? **Answer:** No. App Check attests the app; Auth supplies identity; rules authorize that identity's data operations.

### O3. Two-account sharing and scope switching

- **Files/symbols:** `lib/features/family/data/family_repository.dart:36–72,145–238`, `_bindAccount/_listenToFamily/_listenToMembers/retry`; `lib/features/pantry/data/pantry_repository.dart:62–129`, `scopePath/_listenToItems`; `lib/features/grocery/data/grocery_repository.dart:136–166,177–286`, scope and active-list listeners; `lib/features/meal_plan/data/saved_plans_repository.dart:86–181`, plan feed/session reset.
- **Trigger/flow:** Auth identity → membership index → current household and member stream → scoped food listeners → notifier → each signed-in phone's widgets.
- **Validation/data:** Same-household accounts share paths under `families/{id}`. Personal data stays under `users/{uid}`; joining is not a migration/copy of personal documents. Revoked membership changes the authorized scope. Account changes cancel old listeners and advance epochs.
- **Loading/failure:** Firestore source code supports real-time updates; it is not proof that two physical phones synchronized during this documentation task. Demonstrate a real observed update or state that it was not confirmed. Never claim a delayed cached display proves server synchronization.
- **Say aloud:** “The second account is not reading the first user's private collection. Both authorized accounts subscribe to their household paths. Firestore streams notify each repository, and the UI rebuilds. If the account or membership changes, old streams are cancelled and version checks reject their late callbacks.”
- **Question:** Why test two different accounts instead of one account on two phones? **Answer:** Different UIDs demonstrate household authorization and separate read states; the same UID would not establish account isolation.

### O4. Atomic shared activity and personal read receipts

- **Files/symbols:** `lib/features/pantry/data/pantry_store.dart:8–48`, `PantryStore.write`; `lib/core/services/household_activity_store.dart:16–57,78–174`, `HouseholdActivityStore.publish/markRead/watch`; `lib/core/services/notification_service.dart:63–91,131–189,510–555`, merged feed and `markRead/markAllRead`; `lib/core/models/app_notification.dart:50–55`, type display label; `lib/core/widgets/app_shell.dart:88–130`, unread badge.
- **Trigger/flow:** Pantry edit writes stock plus a household activity event atomically → the member's activity stream merges with their receipt stream → inbox and badge rebuild → opening stores only that user's read receipt.
- **Validation/data:** Event type is `pantryItemUpdated`, with `includeSelf:false`. The receiving member sees title **Pantry**, body **A household member updated pantry stock.** Receipts are `users/{uid}/notificationReceipts/household:{familyId}:{eventId}`. Events before a member's `joinedAt` are filtered out.
- **Loading/failure:** Shared feed waits for both event and receipt data, exposes errors and can retry. Do not promise an event for every possible operation: inspected grocery checking and join/role paths do not create the same activity. Manual grocery activity is best-effort, unlike the atomic pantry event.
- **Say aloud:** “We store the shared event once under the household, then keep each user's read receipt separately. That avoids writing into every other user's private notification collection. The pantry update and event are atomic, and the actor is excluded. Reading the event on one account does not mark it read for everyone.”
- **Question:** Why did the owner not receive their own update? **Answer:** Pantry activity explicitly excludes its actor; use the other member's inbox to demonstrate reception.

### O5. Notification navigation and native-push limits

- **Files/symbols:** `lib/features/notifications/pages/notifications_page.dart:18–45,69–104`, `NotificationsPage/NotificationInbox._run`; `lib/core/routing/notification_route.dart:6–74`, `notificationRoute`; `lib/features/notifications/pages/notification_target_page.dart:9–98`, `NotificationTargetPage`; `lib/core/services/notification_service.dart:197–243,319–395`, lifecycle/token/feed handling; `lib/main.dart:31–34,157–160,230–299`, background entry and navigation setup.
- **Trigger/flow:** Tap card → awaited `markRead` → type-specific route. Pantry/grocery events open tabs. Meal events resolve an authorized loaded plan/meal target rather than manufacturing a missing draft. Native FCM interactions enter a separate authenticated/session-checked navigation path.
- **Validation/data:** Pending actions capture account/session context. Deleted, inaccessible or ambiguous meal targets show a recovery state, not another user's meal. Release App Check uses Play Integrity/DeviceCheck; debug/test paths are separate, and the obsolete Android release override is removed.
- **Loading/failure:** Inbox action errors display feedback; mark-all-read affects the current user. In-app delivery and Android background push are different systems. A trusted sender and end-to-end physical-device acceptance are not established merely by having `firebase_messaging` code.
- **Say aloud:** “Tapping an alert first updates this account's read state, then routes using the event type and authorized target. If the meal is gone or the account changed, it shows recovery instead of opening a guessed item. Our demonstration proves only the in-app actions we actually observe, not background push delivery.”
- **Question:** Do household notifications require Cloud Functions here? **Answer:** The demonstrated in-app activity/receipt feed does not. Native remote push would require a trusted sender; no Functions deployment or billing change is claimed.

## Important honest answers and verification boundaries

- **“Did you test two physical phones?”** The coding agent did not. Report only the presenters' actual preflight observations as user-verified; distinguish those from emulator and automated results.
- **“Does every provider/model work?”** Adapters and registry validation are implemented. The retained live evidence covers a bounded Gemini model workflow, not every selectable model or account's quota.
- **“Can you demonstrate everything offline?”** No. Cached data can help, but live generation, account actions, shared server confirmation and many writes require connectivity.
- **“Is the app production-ready?”** This is an academic prototype. Shared APK credentials are extractable, private provider storage is not a hardware vault, the cooperative quota is not authoritative anti-abuse protection, and native push/physical multi-device acceptance remain limited.
- **“Was the old exposed App Check secret revoked?”** No revocation is established. The owner explicitly accepted that existing Git-history risk for the source push. Removing a debug override from current code does not revoke a registered credential. Never reveal the value in a defense.
- **“Did these documents fix code or rebuild the APK?”** No. This task inspected source and created presentation documentation only.

## Features deliberately not performed in the ten-minute live sequence

Fresh account registration/email delivery, password reset/change, invitation redemption, membership removal/rejoining, ownership transfer, archival/deletion, new AI replacement, provider import/switching, destructive grocery clearing, permission-denial recovery, offline restart and native background push are explained here or rehearsed separately. They are omitted from the timer because they add waiting, risk or duplicate coverage—not because their mere presence in code proves them working.
