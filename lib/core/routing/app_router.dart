import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/meal_plan/pages/meal_plan_page.dart';
import '../../features/meal_plan/pages/saved_meal_plans_page.dart';
import '../../features/meal_plan/pages/generated_meal_plan_page.dart';
import '../../features/pantry/pages/pantry_page.dart';
import '../../features/grocery/pages/grocery_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/meal/pages/meal_detail_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/family/pages/family_space_page.dart';
import '../../features/ai_settings/pages/ai_settings_page.dart';
import '../../features/notifications/pages/notifications_page.dart';
import '../../features/meal_plan/models/saved_meal_plan.dart';

/// Builds the GoRouter instance wired with [AuthRepository] for authentication redirects.
GoRouter createAppRouter(AuthRepository authRepository) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authRepository,
    redirect: (context, state) {
      final isLoggedIn = authRepository.isAuthenticated;
      final matched = state.matchedLocation;
      final isAuthRoute = matched == '/login' || matched == '/register' || matched == '/forgot-password';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
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
        path: '/generated-plan',
        builder: (context, state) {
          final extra = state.extra;
          return GeneratedMealPlanPage(
            draft: extra is GeneratedPlanDraft ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/family-space',
        builder: (context, state) => const FamilySpacePage(),
      ),
      GoRoute(
        path: '/ai-settings',
        builder: (context, state) => const AiSettingsPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/meal/:mealId',
        builder: (context, state) => MealDetailPage(
          mealId: state.pathParameters['mealId']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        redirect: (context, state) => '/ai-settings',
      ),
      GoRoute(
        path: '/family',
        redirect: (context, state) => '/family-space',
      ),
    ],
  );
}
