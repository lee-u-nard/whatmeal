import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whatmeal/core/services/family_service.dart';
import 'package:whatmeal/core/services/notification_service.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/grocery/data/grocery_repository.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';
import 'package:whatmeal/features/grocery/pages/grocery_page.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:whatmeal/features/notifications/pages/notifications_page.dart';
import 'package:whatmeal/features/pantry/data/pantry_repository.dart';
import 'package:whatmeal/features/pantry/data/pantry_store.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('shared household food recovery and private receipt isolation',
      (tester) async {
    expect(appFlavor, 'local');
    const host = '10.0.2.2';
    await Firebase.initializeApp();
    expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8180);
    final normal = FirebaseAuth.instance;
    await normal.useAuthEmulator(host, 9099);
    final baseline = await normal.authStateChanges().first;
    expect(baseline, isNotNull);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final apps = <FirebaseApp>[];
    final accounts = [
      ValueNotifier<UserModel?>(null),
      ValueNotifier<UserModel?>(null)
    ];
    final auths = <FirebaseAuth>[];
    final dbs = <FirebaseFirestore>[];
    final families = <FamilyRepository>[];
    final plans = <SavedPlansRepository>[];
    final pantries = <PantryRepository>[];
    final groceries = <GroceryRepository>[];
    final inboxes = <NotificationService>[];
    var denyMemberPantry = false;
    final phases = <String>[];
    final rpcFailures = <String>[];
    binding.reportData = {
      'phases': phases,
      'rpcFailures': rpcFailures,
      'normalLoginPreserved': false,
      'scope':
          'Two named native Firebase clients on one AVD; disposable household; real GroceryPage/NotificationsPage; not two devices or full routed app demo'
    };
    void checkpoint(String label) {
      phases.add(label);
      debugPrint('Shared food checkpoint: $label');
    }

    // Local emulator-only helpers are inserted from the verified recovery harness.
    Future<void> until(bool Function() ready) async {
      for (var n = 0; n < 1200 && !ready(); n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(ready(), isTrue, reason: 'Bounded local food phase must complete');
    }

    Future<void> transport(bool pause) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.postUrl(
            Uri.parse('http://$host:8184/${pause ? "pause" : "resume"}'));
        request.followRedirects = false;
        final response = await request.close();
        expect(response.statusCode, 200);
        expect(
            (jsonDecode(await utf8.decoder.bind(response).join())
                as Map)['paused'],
            pause);
      } finally {
        client.close();
      }
    }

    Future<UserModel> register(FirebaseAuth auth, String label) async {
      final email = 'food-${label.toLowerCase()}-$stamp@example.test';
      final result = await auth.createUserWithEmailAndPassword(
          email: email, password: 'Disposable-local-123!');
      await result.user!.updateDisplayName(label);
      await result.user!.sendEmailVerification();
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final response = await (await client.getUrl(Uri.parse(
                'http://$host:9199/emulator/v1/projects/demo-whatmeal-audit/oobCodes')))
            .close();
        expect(response.statusCode, 200);
        final codes = (jsonDecode(await utf8.decoder.bind(response).join())
            as Map)['oobCodes'] as List;
        final code = codes.lastWhere((entry) =>
            entry['email'] == email && entry['requestType'] == 'VERIFY_EMAIL');
        await auth.applyActionCode(code['oobCode'] as String);
        await auth.currentUser!.reload();
        await auth.currentUser!.getIdToken(true);
        expect(auth.currentUser!.emailVerified, isTrue);
        return UserModel(
            id: auth.currentUser!.uid,
            name: label,
            email: email,
            isEmailVerified: true);
      } finally {
        client.close();
      }
    }

    Future<DocumentSnapshot<Map<String, dynamic>>> serverGet(
        FirebaseFirestore db, String path) async {
      for (var attempt = 0;; attempt++) {
        try {
          return await db
              .doc(path)
              .get(const GetOptions(source: Source.server));
        } on FirebaseException catch (error) {
          if (!['unavailable', 'deadline-exceeded'].contains(error.code) ||
              attempt >= 29) {
            rethrow;
          }
          await tester.pump(const Duration(seconds: 1));
        }
      }
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      expect(finder.first.hitTestable(), findsOneWidget);
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    try {
      await transport(false);
      for (var i = 0; i < 2; i++) {
        final app = await Firebase.initializeApp(
            name: 'shared-food-$i-$stamp', options: Firebase.app().options);
        apps.add(app);
        final auth = FirebaseAuth.instanceFor(app: app);
        auths.add(auth);
        await auth.useAuthEmulator(host, 9199);
        final db = FirebaseFirestore.instanceFor(app: app);
        db.settings = const Settings(persistenceEnabled: false);
        db.useFirestoreEmulator(host, i == 0 ? 9180 : 8183);
        dbs.add(db);
        accounts[i].value =
            await register(auth, i == 0 ? 'SharedOwner' : 'SharedMember');
        families.add(FamilyRepository(
            firestore: db,
            authIds: auth.authStateChanges().map((u) => u?.uid),
            account: accounts[i]));
      }
      final owner = accounts[0].value!;
      final member = accounts[1].value!;
      final ownerService = FamilyService(firestore: dbs[0]);
      final memberService = FamilyService(firestore: dbs[1]);
      final familyId = await ownerService.createFamily(
          name: 'Disposable shared food',
          uid: owner.id,
          displayName: owner.name);
      final token = await ownerService.createInvitation(
          familyId: familyId, uid: owner.id);
      await memberService.joinFamily(
          inviteCode: token, uid: member.id, displayName: member.name);
      await until(() =>
          families.every((f) => f.value?.members.length == 2 && !f.isLoading));
      checkpoint(
          'two verified disposable accounts created and joined household through actual SDK services');

      for (var i = 0; i < 2; i++) {
        final db = dbs[i];
        final auth = auths[i];
        final household = families[i];
        bool canEdit() =>
            household.value?.members.any(
                (m) => m.id == accounts[i].value?.id && m.role.canAcceptMeal) ==
            true;
        final saved = SavedPlansRepository(
            firestore: db,
            account: accounts[i],
            household: household,
            canEditShared: canEdit);
        plans.add(saved);
        final pantry = PantryRepository(
            firestore: db,
            authIds: auth.authStateChanges().map((u) => u?.uid),
            household: household,
            watch: (path) => db
                .collection(i == 1 && denyMemberPantry
                    ? 'users/${owner.id}/pantryItems'
                    : path)
                .snapshots()
                .map((s) => s.docs.map(PantryItem.fromFirestore).toList()));
        pantries.add(pantry);
        groceries.add(GroceryRepository(
            firestore: db,
            authIds: auth.authStateChanges().map((u) => u?.uid),
            household: household,
            plans: saved,
            pantry: pantry,
            pantryScope: () => pantry.scopePath,
            canEdit: canEdit));
        inboxes.add(NotificationService(
            firestore: db,
            userIds: auth.authStateChanges().map((u) => u?.uid),
            household: household));
      }
      final root = 'families/$familyId';
      final stock = PantryItem(
          name: 'rice', quantity: '2 cups', expirationDate: DateTime(2030));
      await PantryStore(dbs[0]).write(
          item: dbs[0].doc('$root/pantryItems/rice'),
          actorUid: owner.id,
          action: 'added',
          data: stock.toFirestore());
      final planId = await plans[0].savePlan(
          MealPlan(
              id: '',
              title: 'Shared manual week',
              createdBy: owner.id,
              startDate: DateTime(2027, 1, 4),
              endDate: DateTime(2027, 1, 8)),
          [
            Meal(id: 'one', title: 'Rice one', ingredients: [
              const Ingredient(name: 'rice', amount: '3 cups')
            ]),
            Meal(id: 'two', title: 'Rice two', ingredients: [
              const Ingredient(name: 'rice', amount: '2 cups')
            ]),
          ]);
      final path = '$root/mealPlans/$planId';
      await until(() => plans.every((p) =>
          p.value.any((v) => v.sourcePath == path && v.meals.length == 2)));
      expect(plans[1].value.singleWhere((p) => p.sourcePath == path).startDate,
          DateTime(2027, 1, 4));
      await plans[1]
          .updateMealStatus('one', MealStatus.accepted, planPath: path);
      await plans[0]
          .updateMealStatus('two', MealStatus.accepted, planPath: path);
      await until(() => groceries.every((g) =>
          !g.isLoading &&
          g.error == null &&
          g.allItems.length == 1 &&
          g.allItems.single.quantity == '3 cup'));
      expect(groceries[1].allItems.single.sourceMealPaths.length, 2);
      checkpoint(
          'saved dates and two accepted meals synchronized with exact consolidated pantry shortage');

      await tester
          .pumpWidget(MaterialApp(home: GroceryPage(repository: groceries[1])));
      denyMemberPantry = true;
      pantries[1].retry();
      await until(() => groceries[1].error != null);
      await tester.pumpAndSettle();
      expect(find.text('Pantry stock could not be loaded. Please retry.'),
          findsOneWidget);
      expect(groceries[1].allItems, isEmpty);
      expect(groceries[0].allItems.single.quantity, '3 cup');
      denyMemberPantry = false;
      await tap(find.text('Retry'));
      await until(() =>
          groceries[1].error == null &&
          !groceries[1].isLoading &&
          groceries[1].allItems.single.quantity == '3 cup');
      checkpoint(
          'member private-account query denied and visible Grocery Retry recovered without disrupting owner');

      await transport(true);
      await PantryStore(dbs[0]).write(
          item: dbs[0].doc('$root/pantryItems/rice'),
          actorUid: owner.id,
          action: 'updated',
          data: stock.copyWith(quantity: '4 cups').toFirestore());
      String? failure;
      try {
        await plans[1]
            .updateMealStatus('one', MealStatus.completed, planPath: path);
      } on FirebaseException catch (error) {
        failure = error.code;
        rpcFailures.add(error.code);
      }
      expect(
          ['unavailable', 'deadline-exceeded', 'unknown'], contains(failure));
      expect((await serverGet(dbs[0], '$path/meals/one')).data()?['status'],
          'accepted');
      await transport(false);
      await until(() => groceries.every((g) =>
          g.error == null &&
          !g.isLoading &&
          g.allItems.length == 1 &&
          g.allItems.single.quantity == '1 cup'));
      checkpoint(
          'owner pantry update survived member interruption and failed meal transaction did not commit');

      await tester.pumpAndSettle();
      await tap(find.byType(Checkbox).first);
      await until(() => groceries.every((g) => g.allItems.single.isPurchased));
      await dbs[1].waitForPendingWrites();
      final receipt = await serverGet(dbs[0],
          '$root/groceryLists/default/items/${groceries[0].allItems.single.id}');
      expect(receipt.data()?['quantity'], '1 cup');
      expect((receipt.data()?['sourceMealPaths'] as List).length, 2);
      checkpoint(
          'member Grocery checkbox persisted receipt and owner listener received purchase provenance');

      final duplicate = await Future.wait([
        groceries[0]
            .addItem('Other', GroceryItem(name: 'salt', quantity: '1 pack')),
        groceries[1]
            .addItem('Other', GroceryItem(name: 'salt', quantity: '1 pack')),
      ]);
      expect(duplicate.where((added) => added).length, 1);
      await until(() => groceries
          .every((g) => g.allItems.where((v) => v.name == 'salt').length == 1));
      checkpoint(
          'concurrent household grocery additions produced one shared manual item');

      await until(() => inboxes
          .every((s) => !s.isLoading && s.error == null && s.unreadCount > 0));
      final ownerUnread = inboxes[0].unreadCount;
      await tester.pumpWidget(
          MaterialApp(home: NotificationsPage(service: inboxes[1])));
      await tester.pumpAndSettle();
      await tap(find.text('Mark all read'));
      await until(() => inboxes[1].unreadCount == 0);
      await dbs[1].waitForPendingWrites();
      expect(inboxes[0].unreadCount, ownerUnread);
      expect(
          (await dbs[1]
                  .collection('users/${member.id}/notificationReceipts')
                  .get(const GetOptions(source: Source.server)))
              .size,
          greaterThan(0));
      checkpoint(
          'household notification history loaded and member read receipts remained private');

      await plans[1]
          .updateMealStatus('one', MealStatus.completed, planPath: path);
      await until(() => plans[0]
          .value
          .singleWhere((p) => p.sourcePath == path)
          .meals
          .any((m) => m.id == 'one' && m.status == MealStatus.completed));
      await plans[0].deleteMeal(path, 'one');
      await until(() => groceries.every((g) =>
          g.allItems
              .where((v) => v.name == 'rice')
              .single
              .sourceMealPaths
              .length ==
          1));
      expect(
          groceries[0].allItems.singleWhere((v) => v.name == 'rice').quantity,
          '0 cup');
      checkpoint(
          'ordinary meal retry completed and deletion preserved the other accepted meal source');

      expect(await families[0].removeMember(member.id), isTrue);
      await until(() =>
          families[1].value == null &&
          groceries[1].allItems.isEmpty &&
          pantries[1].items.isEmpty &&
          plans[1].value.isEmpty &&
          inboxes[1].value.isEmpty);
      String? denial;
      try {
        await serverGet(dbs[1], '$path/meals/two');
      } on FirebaseException catch (error) {
        denial = error.code;
      }
      expect(denial, 'permission-denied');
      final freshToken = await ownerService.createInvitation(
          familyId: familyId, uid: owner.id);
      await memberService.joinFamily(
          inviteCode: freshToken, uid: member.id, displayName: member.name);
      await until(() =>
          families[1].value?.id == familyId &&
          groceries[1].allItems.length == 2);
      checkpoint(
          'removal cleared shared food and inbox access; fresh invitation legitimately restored household');
      expect(normal.currentUser?.uid, baseline?.uid);
      binding.reportData!['normalLoginPreserved'] = true;
      await tester
          .pumpWidget(MaterialApp(home: GroceryPage(repository: groceries[1])));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('shared-food-recovered');
      checkpoint(
          'normal cached login unchanged after two-account recovery acceptance');
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (final g in groceries) {
        g.dispose();
      }
      for (final p in pantries) {
        p.dispose();
      }
      for (final p in plans) {
        p.dispose();
      }
      for (final n in inboxes) {
        n.dispose();
      }
      for (final f in families) {
        f.dispose();
      }
      await transport(false);
      for (final a in auths) {
        await a.signOut();
      }
      for (final a in accounts) {
        a.dispose();
      }
      expect(normal.currentUser?.uid, baseline?.uid);
      for (final a in apps) {
        await a.delete();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
