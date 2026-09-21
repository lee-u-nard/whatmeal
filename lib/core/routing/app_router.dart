import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';
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

final appRouter = GoRouter(
  initialLocation: '/home',
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
      builder: (context, state) => const GeneratedMealPlanPage(),
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
  ],
);
