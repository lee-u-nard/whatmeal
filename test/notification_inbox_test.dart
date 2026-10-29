import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/features/notifications/pages/notifications_page.dart';

void main() {
  Future<void> show(WidgetTester tester,
      {bool loading = false,
      String? error,
      List<AppNotification> items = const [],
      VoidCallback? retry,
      Future<void> Function()? markAll,
      Future<void> Function(AppNotification)? open}) async {
    await tester.pumpWidget(MaterialApp(
        home: NotificationInbox(
            notifications: items,
            isLoading: loading,
            error: error,
            onRetry: retry ?? () {},
            onBack: () {},
            onMarkAllRead: markAll ?? () async {},
            onOpen: open ?? (_) async {})));
    await tester.pump();
  }

  testWidgets(
      'loading and listener error are distinct from empty inbox; retry works',
      (tester) async {
    await show(tester, loading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No notifications yet'), findsNothing);
    var retries = 0;
    await show(tester,
        error: 'Notifications could not be loaded.', retry: () => retries++);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    expect(find.text('No notifications yet'), findsNothing);
    await show(tester);
    expect(find.text('No notifications yet'), findsOneWidget);
  });
  testWidgets(
      'mark-all failure is visible and sanitized; tapping receives exact target',
      (tester) async {
    final item = AppNotification(
        id: 'local-event',
        title: 'Local meal',
        body: 'Updated',
        type: AppNotificationType.mealAccepted,
        createdAt: DateTime.now(),
        read: false,
        navigationParameters: const {
          'planPath': 'families/local/mealPlans/plan',
          'mealId': 'meal'
        });
    AppNotification? opened;
    await show(tester, items: [item], markAll: () async {
      throw StateError('Secret exception');
    }, open: (value) async {
      opened = value;
    });
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(
        find.text('Notification change failed. Please retry.'), findsOneWidget);
    expect(find.textContaining('Secret exception'), findsNothing);
    await tester.tap(find.text('Local meal'));
    await tester.pumpAndSettle();
    expect(opened?.navigationParameters?['planPath'],
        'families/local/mealPlans/plan');
    expect(tester.takeException(), isNull);
  });
}
