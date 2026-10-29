# WhatMeal audit — 2026-10-04

## Scope and initial plan

This is a staged audit of the existing Flutter app. Production data, deployments,
paid services, destructive migrations, and branding changes are excluded.

1. Inventory source, platform configuration, dependencies, backend, and tests.
2. Trace authentication, household membership/roles, and personal/shared data paths.
3. Trace meals, pantry, groceries, notifications, and AI configuration/generation.
4. Fix independently understood defects, starting with security and account isolation.
5. Run static analysis, automated tests, and Android release build where supported.
6. Record verified results, unresolved findings, and a precise continuation plan.

## Architecture observed

- Feature-first Flutter UI; GoRouter with five persistent navigation branches.
- Firebase Auth email/password and verification; UID-keyed user documents.
- ValueNotifier/ChangeNotifier repositories with Firestore listeners.
- Personal data: users/{uid}; shared data: families/{familyId}.
- Separate household membership documents and dietary family-profile documents.
- Meal plans contain nested meals; two repositories expose different representations.
- Firebase AI Logic default plus Gemini REST, OpenAI, Anthropic, Groq, custom adapters.
- Owner-only Firestore API-key document and an in-memory key cache.
- Local/FCM notification service and optional Node Cloud Functions source.

## Initial findings (not yet a complete audit)

- CRITICAL: Any authenticated user can enumerate households and invite codes, then
  add themselves to any household. Secure invitation lookup requires a coordinated
  client/rules data-model change and handling of existing household invitations.
- CRITICAL: Shared recursive write rule bypasses role checks, including membership
  role edits; view-only restrictions exist only in the client.
- HIGH: Removing another member/deleting a populated household writes other users'
  private documents, which current rules deny. Deletion assumes an unavailable
  Cloud Function cascade on Spark.
- HIGH: Family listener scope survives logout; signing back into the same household
  can skip reattaching its listener.
- HIGH: In-flight saved-plan/config reads can publish data after the account changes.
- HIGH: Provider switching retains the previous provider's API key and can send it
  to a different provider/custom endpoint.
- HIGH: API-key memory cache can override newer saved provider credentials.
- HIGH: Release startup uses debug App Check providers and a placeholder web key.
- MEDIUM: Notification navigation uses Navigator named routes with GoRouter.
- MEDIUM: Grocery initialization is a one-time read with racing auto-create operations.
- MEDIUM: Gemini quota read/increment is nontransactional and happens after requests.
- MEDIUM: Tests labelled isolation/synchronization largely test models and strings,
  not rules, authenticated clients, transactions, or actual synchronized listeners.
- LOW: README describes placeholder screens despite implemented features.

## Verification policy

Source inspection is not runtime verification. Provider compatibility needs mocked
transport tests and authorized live requests; no credentials will be printed.
Rules require emulator tests with owner, admin, member, view-only, and outsider
identities. No production writes or backend deployments will be used for testing.

## Stage 1 checkpoint — 2026-10-05

See [audit/REPORT.md](audit/REPORT.md) for the complete finding register, changes,
verification evidence, limitations, and prioritized continuation plan.
Final static analysis: no issues. Final tests: 47 passed. Android release build
blocked before compilation by Gradle loopback failure. Critical deployed rules
remain unresolved; no production changes or rules deployment performed.
