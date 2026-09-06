
# WhatMeal

AI-powered family meal planning and food management app, built with Flutter.

## Tech Stack

- **Flutter** (Material 3)
- **go_router** — navigation, using `StatefulShellRoute` for persistent tab navigation
- More to come as features are built out (state management, API client, local storage)

## Project Structure

The app follows a **feature-first** layout: code is grouped by domain (`home`, `meal_plan`, etc.) rather than by type, so each feature's files live together.

```
lib/
├── main.dart                     # entry point only — calls runApp()
├── app.dart                      # MaterialApp.router + theme + routerConfig
├── core/                         # shared across every feature
│   ├── routing/
│   │   └── app_router.dart       # GoRouter config — all routes/branches defined here
│   └── widgets/
│       └── app_shell.dart        # persistent header + bottom nav shell
└── features/
    ├── home/
    │   └── pages/
    │       └── home_page.dart
    ├── meal_plan/
    │   └── pages/
    │       └── meal_plan_page.dart
    ├── pantry/
    │   └── pages/
    │       └── pantry_page.dart
    ├── grocery/
    │   └── pages/
    │       └── grocery_page.dart
    └── profile/
        └── pages/
            └── profile_page.dart
```

**Conventions:**
- File names: `snake_case.dart`
- Class names: `PascalCase`, matching the file's purpose
- One public widget per file
- Screens live in a feature's `pages/` folder; widgets used only by that feature go in a sibling `widgets/` folder (add as needed)
- Don't add `data/`/`domain/` subfolders to a feature until it actually needs its own API calls or repository — avoid structure with no code behind it yet

## Getting Started

```bash
flutter pub get
flutter run
```

Pick a device/emulator if prompted. While running: `r` for hot reload, `R` for hot restart (use hot restart after structural/router changes).

## Navigation

The app has 5 tabs, each its own route branch via `StatefulShellRoute.indexedStack` — every tab keeps its own state when you switch away and back:

| Tab | Route |
|---|---|
| Home | `/home` |
| Meal Plan | `/meal-plan` |
| Pantry | `/pantry` |
| Grocery | `/grocery` |
| Profile | `/profile` |

All navigation and the shared header live in `core/widgets/app_shell.dart` — pages themselves contain **only their body content**, no `Scaffold`. The header's profile icon (top-right) jumps directly to the Profile tab rather than opening a separate screen.

## Current Progress

- [x] Project scaffolding and feature-first folder structure
- [x] Shared `AppShell` — header (with profile shortcut) + bottom nav
- [x] 5-tab routing via `go_router` (`StatefulShellRoute`)
- [ ] Real content for each tab (currently placeholder screens)
- [ ] State management
- [ ] API / data layer for meal plans, pantry, grocery
- [ ] Testing
- [ ] Theming and production polish

## Notes for the Team

- Each tab page is currently a placeholder (`Center(child: Text('...'))`) — safe to build on top of without touching routing or the shell.
- If you need a new top-level route (not a tab), add it as a `GoRoute` outside the `StatefulShellRoute` in `app_router.dart` (e.g. a settings page pushed on top of everything).
- Keep new dependencies to what's actually needed for the feature you're building — avoid pulling in packages "just in case."