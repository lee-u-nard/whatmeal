import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';
import '../services/auth_service.dart';
import '../../features/home/auth/login_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/meal_plan/pages/meal_plan_page.dart';
import '../../features/meal_plan/pages/saved_meal_plans_page.dart';
import '../../features/pantry/pages/pantry_page.dart';
import '../../features/grocery/pages/grocery_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/family_page.dart';
import '../../features/profile/pages/settings_page.dart';
import '../../features/meal/pages/meal_detail_page.dart';

/// Builds the GoRouter instance wired with [AuthService] for authentication redirects.
GoRouter createAppRouter(AuthService authService) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authService,
    redirect: (context, state) {
      final isLoggedIn = authService.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
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
        ],
      ),
      GoRoute(
        path: '/saved-meal-plans',
        builder: (context, state) => const SavedMealPlansPage(),
      ),
      GoRoute(
        path: '/meal/:mealId',
        builder: (context, state) => MealDetailPage(
          mealId: state.pathParameters['mealId']!,
          planId: state.uri.queryParameters['planId'],
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/family',
        builder: (context, state) => const FamilyPage(),
      ),
    ],
  );
}
