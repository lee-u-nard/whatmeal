import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/meal_plan/pages/meal_plan_page.dart';
import '../../features/pantry/pages/pantry_page.dart';
import '../../features/grocery/pages/grocery_page.dart';
import '../../features/profile/pages/profile_page.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/meal-plan', builder: (context, state) => const MealPlanPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/pantry', builder: (context, state) => const PantryPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/grocery', builder: (context, state) => const GroceryPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
        ]),
      ]
    ),
  ],
);
