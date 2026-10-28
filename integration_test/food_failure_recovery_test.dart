import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/grocery/data/grocery_repository.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';
import 'package:whatmeal/features/grocery/pages/grocery_page.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plan_stream.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/pantry/data/pantry_repository.dart';
import 'package:whatmeal/features/pantry/data/pantry_store.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';
import 'package:whatmeal/features/pantry/widgets/add_pantry_item_sheet.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('local meal pantry grocery transaction and terminal recovery',
      (tester) async {
    expect(appFlavor, 'local');
    const host = '10.0.2.2';
    await Firebase.initializeApp();
    expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
    // Guard even incidental singleton initialization against non-emulator traffic.
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8180);
    final normal = FirebaseAuth.instance;
    await normal.useAuthEmulator(host, 9099);
    final baseline = await normal.authStateChanges().first;
    expect(baseline != null, isTrue);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final fixture = await Firebase.initializeApp(
        name: 'food-$stamp', options: Firebase.app().options);
    final auth = FirebaseAuth.instanceFor(app: fixture);
    await auth.useAuthEmulator(host, 9199);
    final db = FirebaseFirestore.instanceFor(app: fixture);
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(host, 8183);
    final account = ValueNotifier<UserModel?>(null);
    final household = ValueNotifier<FamilySpace?>(null);
    SavedPlansRepository? plansRepo;
    PantryRepository? pantryRepo;
    GroceryRepository? groceryRepo;
    var denyPantry = false, denyPlans = false, denyGroceries = false;
    final phases = <String>[];
    final rpcFailures = <String>[];
    binding.reportData = {
      'phases': phases,
      'rpcFailures': rpcFailures,
      'normalLoginPreserved': false,
      'scope':
          'Disposable personal account; real Android GroceryPage and pantry editor/native SDK; no live AI'
    };
    void checkpoint(String text) {
      phases.add(text);
      debugPrint('Local food checkpoint: $text');
    }

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
      account.value = await register(auth, 'Owner');
      final uid = account.value!.id;
      final root = 'users/$uid';
      final plans = plansRepo = SavedPlansRepository(
          firestore: db,
          account: account,
          household: household,
          canEditShared: () => true,
          watch: (query) => watchSavedPlans(denyPlans
              ? db.collection('users/no-food-access-$stamp/mealPlans')
              : query));
      final pantry = pantryRepo = PantryRepository(
          firestore: db,
          authIds: auth.authStateChanges().map((u) => u?.uid),
          household: household,
          watch: (path) => db
              .collection(
                  denyPantry ? 'users/no-food-access-$stamp/pantryItems' : path)
              .snapshots()
              .map((s) => s.docs.map(PantryItem.fromFirestore).toList()));
      final groceries = groceryRepo = GroceryRepository(
          firestore: db,
          authIds: auth.authStateChanges().map((u) => u?.uid),
          household: household,
          plans: plans,
          pantry: pantry,
          pantryScope: () => pantry.scopePath,
          canEdit: () => true,
          watchItems: (items) => (denyGroceries
                  ? db.collection(
                      'users/no-food-access-$stamp/groceryLists/default/items')
                  : items)
              .snapshots()
              .map((s) => s.docs.map(GroceryItem.fromFirestore).toList()));
      final stock = db.doc('$root/pantryItems/rice');
      final store = PantryStore(db);
      await store.write(
          item: stock,
          actorUid: uid,
          action: 'added',
          data: PantryItem(
                  name: 'rice',
                  quantity: '2 cups',
                  expirationDate: DateTime(2030))
              .toFirestore());
      final planId = await plans.savePlan(
          MealPlan(
              id: '',
              title: 'Disposable food week',
              createdBy: uid,
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
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  appBar: AppBar(
                      title: const Text('Disposable recovery'),
                      actions: [
                        TextButton(
                            onPressed: () {
                              showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => AddPantryItemSheet(
                                      existingItem: pantry.items.values
                                          .expand((v) => v)
                                          .single,
                                      onSave: (item) async {
                                        try {
                                          await store.write(
                                              item: stock,
                                              actorUid: uid,
                                              action: 'updated',
                                              data: item.item
                                                  .copyWith(
                                                      category: item.category)
                                                  .toFirestore());
                                        } on FirebaseException catch (failure) {
                                          rpcFailures.add(failure.code);
                                          rethrow;
                                        }
                                      }));
                            },
                            child: const Text('Edit stock'))
                      ]),
                  body: GroceryPage(repository: groceries)))));
      await until(() =>
          !plans.isLoading &&
          !pantry.isLoading &&
          !groceries.isLoading &&
          groceries.activeList != null);
      expect(plans.value.single.sourcePath == path, isTrue);
      expect(plans.value.single.startDate, DateTime(2027, 1, 4));
      checkpoint(
          'manual saved plan identity and dates persisted with two pending meals');
      await transport(true);
      String? acceptFailure;
      try {
        await plans.updateMealStatus('one', MealStatus.accepted,
            planPath: path);
      } on FirebaseException catch (failure) {
        acceptFailure = failure.code;
        rpcFailures.add(failure.code);
      }
      // Android can report a failed Dart handler as UNKNOWN; retain the code.
      // It must still fail and the server must prove the meal stayed pending.
      expect(['unavailable', 'deadline-exceeded', 'unknown'],
          contains(acceptFailure));
      await transport(false);
      expect((await serverGet(db, '$path/meals/one')).data()?['status'],
          'pending');
      checkpoint('offline meal acceptance failed without committing status');
      await plans.updateMealStatus('one', MealStatus.accepted, planPath: path);
      await until(() =>
          groceries.allItems.length == 1 &&
          groceries.allItems.single.quantity == '1 cup');
      await plans.updateMealStatus('two', MealStatus.accepted, planPath: path);
      await until(() => groceries.allItems.single.quantity == '3 cup');
      expect(groceries.allItems.single.sourceMealPaths.length, 2);
      final receipt = db.doc(
          '$root/groceryLists/${groceries.activeList!.id}/items/${groceries.allItems.single.id}');
      checkpoint(
          'acceptance retry and shared ingredient consolidation produced exact pantry shortage');
      denyPantry = true;
      pantry.retry();
      await until(() => pantry.error != null && groceries.error != null);
      await tester.pumpAndSettle();
      expect(find.text('Pantry stock could not be loaded. Please retry.'),
          findsOneWidget);
      expect(groceries.allItems, isEmpty);
      await expectLater(
          groceries.setPurchased(receipt.id, true), throwsStateError);
      expect((await serverGet(db, receipt.path)).exists, isFalse);
      checkpoint(
          'real pantry permission denial hid inflated shopping needs and rejected stale purchase');
      denyPantry = false;
      await tap(find.text('Retry'));
      await until(() =>
          groceries.error == null &&
          !groceries.isLoading &&
          groceries.allItems.single.quantity == '3 cup');
      checkpoint(
          'grocery Retry reopened pantry feed and restored exact shortage');
      denyPlans = true;
      plans.retry();
      await until(() => plans.error != null && groceries.error != null);
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Meal shopping requirements could not be loaded. Please retry.'),
          findsOneWidget);
      expect(groceries.allItems, isEmpty);
      denyPlans = false;
      await tap(find.text('Retry'));
      await until(() =>
          groceries.error == null &&
          !groceries.isLoading &&
          groceries.allItems.length == 1);
      denyGroceries = true;
      groceries.retry();
      await until(
          () => groceries.error?.contains('Grocery items could not') == true);
      await tester.pumpAndSettle();
      denyGroceries = false;
      await tap(find.text('Retry'));
      await until(() =>
          groceries.error == null &&
          !groceries.isLoading &&
          groceries.allItems.length == 1);
      checkpoint(
          'actual saved-plan and grocery item terminal denials recovered through visible Retry');
      await tap(find.text('Edit stock'));
      tester.testTextInput.register();
      await tester.enterText(
          find
              .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(TextField))
              .at(1),
          '4 cups');
      await tester.pumpAndSettle();
      await transport(true);
      await tap(find.text('Save Changes'));
      await until(() => find
          .text('Ingredient was not saved. Please retry.')
          .evaluate()
          .isNotEmpty);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('4 cups'), findsOneWidget);
      await transport(false);
      expect((await serverGet(db, stock.path)).data()?['quantity'], '2 cups');
      checkpoint(
          'pantry editor retained draft after real offline transaction failure without data loss');
      await tap(find.text('Save Changes'));
      await until(() =>
          find.byType(BottomSheet).evaluate().isEmpty &&
          groceries.allItems.single.quantity == '1 cup');
      await tester.pumpAndSettle();
      await tap(find.byType(Checkbox).first);
      await until(() => groceries.allItems.single.isPurchased);
      await db.waitForPendingWrites();
      final purchased = await serverGet(db, receipt.path);
      expect(purchased.metadata.hasPendingWrites, isFalse);
      expect(purchased.data()?['sourceMealPaths'] is List, isTrue);
      expect((purchased.data()?['sourceMealPaths'] as List).length, 2);
      expect(purchased.data()?['quantity'], '1 cup');
      checkpoint(
          'pantry retry recalculated shortage and actual grocery checkbox persisted provenance');
      final successor = await plans.replaceMeal(
          'one',
          GeneratedMeal.fromCore(Meal(
              id: 'replacement',
              title: 'Beans',
              ingredients: [const Ingredient(name: 'beans', amount: '1 cup')])),
          planPath: path,
          newMealStatus: MealStatus.accepted);
      await until(() =>
          groceries.allItems.length == 2 &&
          groceries.allItems.any((i) => i.name == 'bean'));
      expect(groceries.allItems.singleWhere((i) => i.name == 'rice').quantity,
          '0 cup');
      await plans.deleteMeal(path, successor.id);
      await until(() => groceries.allItems.length == 1);
      expect(groceries.allItems.single.sourceMealPaths.length, 1);
      await plans.updateMealStatus('two', MealStatus.completed, planPath: path);
      await until(() => plans.value.single.meals
          .any((m) => m.id == 'two' && m.status == MealStatus.completed));
      await plans.deleteMeal(path, 'two');
      await until(() => groceries.allItems.isEmpty);
      checkpoint(
          'replacement completion and deletion preserved other meal requirements before removing final source');
      expect(normal.currentUser?.uid == baseline?.uid, isTrue);
      binding.reportData!['normalLoginPreserved'] = true;
      checkpoint(
          'normal cached login unchanged after all disposable food operations');
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('food-recovered');
    } finally {
      await tester.pumpWidget(const SizedBox());
      groceryRepo?.dispose();
      pantryRepo?.dispose();
      plansRepo?.dispose();
      account.dispose();
      household.dispose();
      await transport(false);
      await auth.signOut();
      expect(normal.currentUser?.uid == baseline?.uid, isTrue);
      await fixture.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
