import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/core/services/notification_service.dart';
import 'package:whatmeal/core/widgets/app_shell.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';

void main() {
  testWidgets('header actions are named, navigate, and announce unread changes',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final db = FakeFirebaseFirestore();
    final account = ValueNotifier<UserModel?>(null);
    final family = FamilyRepository(
        firestore: db, authIds: const Stream.empty(), account: account);
    final notifications = NotificationService(
        firestore: db, userIds: const Stream.empty(), household: family);
    final paths = ['/home', '/plans', '/pantry', '/groceries', '/profile'];
    final router = GoRouter(initialLocation: '/home', routes: [
      StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(
              navigationShell: shell,
              familyRepository: family,
              notificationService: notifications),
          branches: [
            for (final path in paths)
              StatefulShellBranch(routes: [
                GoRoute(
                    path: path, builder: (context, state) => Text('Page $path'))
              ])
          ]),
      GoRoute(
          path: '/notifications',
          builder: (context, state) =>
              const Scaffold(body: Text('Notification history')))
    ]);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      router.dispose();
      notifications.dispose();
      family.dispose();
      account.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(
        tester
            .getSemantics(find.byTooltip('Notifications'))
            .getSemanticsData()
            .tooltip,
        'Notifications');
    expect(find.bySemanticsLabel('Open family profiles'), findsOneWidget);
    notifications.value = [
      AppNotification(
          id: 'unread',
          title: 'Update',
          body: 'Local',
          type: AppNotificationType.general,
          createdAt: DateTime(2026))
    ];
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications, 1 unread'), findsOneWidget);
    expect(
        tester
            .getSemantics(find.byTooltip('Notifications, 1 unread'))
            .getSemanticsData()
            .tooltip,
        'Notifications, 1 unread');
    await tester.tap(find.byTooltip('Notifications, 1 unread'));
    await tester.pumpAndSettle();
    expect(find.text('Notification history'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Open family profiles'));
    await tester.pumpAndSettle();
    expect(find.text('Page /profile'), findsOneWidget);
    for (final path in paths) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Narrow header at $path');
    }
    router.go('/pantry');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add pantry item'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('bottom tabs stay above Android system navigation',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final account = ValueNotifier<UserModel?>(null);
    final family = FamilyRepository(
        firestore: db, authIds: const Stream.empty(), account: account);
    final notifications = NotificationService(
        firestore: db, userIds: const Stream.empty(), household: family);
    final router = GoRouter(initialLocation: '/home', routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          familyRepository: family,
          notificationService: notifications,
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home', builder: (context, state) => const SizedBox())
          ])
        ],
      )
    ]);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      router.dispose();
      notifications.dispose();
      family.dispose();
      account.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    for (final label in ['Home', 'Meal Plan', 'Pantry', 'Grocery', 'Profile']) {
      expect(tester.getRect(find.text(label)).bottom, lessThanOrEqualTo(592),
          reason: '$label must be above the 48px Android navigation inset');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
