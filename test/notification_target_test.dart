import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/core/routing/notification_route.dart';
import 'package:whatmeal/core/services/notification_service.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/notifications/pages/notification_target_page.dart';
import 'package:whatmeal/features/notifications/pages/notifications_page.dart';

SavedMealPlan _plan(String path) => SavedMealPlan(
    id: 'same',
    title: path,
    sourcePath: path,
    dates: '',
    mealsCount: 0,
    estCost: '',
    familyMembers: const [],
    meals: const []);

void main() {
  test(
      'notification target retains plan and meal identity, including legacy JSON',
      () {
    const path = 'families/f/mealPlans/p';
    final route = Uri.parse(notificationRoute({
      'navigationParameters': '{"planPath":"$path","mealId":"m"}',
      'navigationRoute': '/generated-plan',
    }));
    expect(route.path, '/notification-target');
    expect(route.queryParameters, {'plan': path, 'mealId': 'm'});
    final activity = Uri.parse(notificationRoute({
      'relatedPlanId': 'p',
      'targetId': 'm',
      'type': 'mealAccepted',
    }));
    expect(activity.queryParameters, {'planId': 'p', 'mealId': 'm'});
  });

  test('unqualified duplicate plan IDs do not select another workspace', () {
    final plans = [
      _plan('users/a/mealPlans/same'),
      _plan('families/f/mealPlans/same')
    ];
    expect(
        resolveNotificationPlan(plans, planPath: null, planId: 'same'), isNull);
    expect(
        resolveNotificationPlan(plans,
            planPath: 'families/f/mealPlans/same', planId: 'same'),
        same(plans.last));
    expect(
        resolveNotificationPlan(plans,
            planPath: 'users/outsider/mealPlans/same', planId: 'same'),
        isNull);
    expect(
        resolveNotificationPlan(plans, planPath: null, planId: null), isNull);
  });

  test('event types without old navigation metadata select supported screens',
      () {
    for (final entry in {
      'pantryItemAdded': '/pantry',
      'groceryItemPurchased': '/grocery',
      'aiProviderChanged': '/ai-settings',
      'memberRemoved': '/family-space',
      'mealPlanSaved': '/saved-meal-plans'
    }.entries) {
      expect(notificationRoute({'type': entry.key}), entry.value);
    }
    expect(notificationRoute({'planPath': '../private', 'route': '/pantry'}),
        '/pantry');
  });

  testWidgets('inbox opens a tab by reusing its existing shell',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final ids = StreamController<String?>.broadcast(sync: true);
    final household = ValueNotifier<FamilySpace?>(null);
    final service = NotificationService(
        firestore: db, userIds: ids.stream, household: household);
    ids.add('a');
    await db.doc('users/a/notifications/event').set(AppNotification(
            id: 'event',
            title: 'Pantry changed',
            body: 'Local fixture',
            type: AppNotificationType.pantryItemAdded,
            createdAt: DateTime(2026),
            read: true,
            navigationRoute: '/pantry')
        .toFirestore());
    final router = GoRouter(initialLocation: '/notifications', routes: [
      StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/home', builder: (_, __) => const Text('Home fixture'))
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/pantry',
                  builder: (_, __) => const Text('Pantry fixture'))
            ]),
          ]),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => NotificationsPage(service: service)),
    ]);
    addTearDown(() async {
      router.dispose();
      service.dispose();
      household.dispose();
      await ids.close();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pantry changed'));
    await tester.pumpAndSettle();
    expect(find.text('Pantry fixture'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'deleted target and account change show recovery, not an empty draft',
      (tester) async {
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'a', name: 'A', email: 'a@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: FakeFirebaseFirestore(),
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) => Stream.value([]));
    addTearDown(() {
      repo.dispose();
      account.dispose();
      household.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        home: NotificationTargetPage(
            repository: repo, planPath: 'users/a/mealPlans/deleted')));
    await tester.pump();
    expect(find.textContaining('This item is no longer available'),
        findsOneWidget);
    account.value = UserModel(id: 'b', name: 'B', email: 'b@example.test');
    await tester.pump();
    expect(find.textContaining('Your account or household changed.'),
        findsOneWidget);
    expect(find.text('Back to notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
