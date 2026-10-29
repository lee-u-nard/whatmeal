import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/grocery/data/grocery_store.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';

void main() {
  test('manual rename preserves fields, rejects collisions and frees old name', () async {
    final db = FakeFirebaseFirestore();
    final store = GroceryStore(db);
    final list = await store.initialize(db.collection('users/a/groceryLists'), 'List');
    await store.addUnique(list, [GroceryItem(name: 'Rice', quantity: '1 kg', status: GroceryStatus.used)]);
    final original = GroceryItem.fromFirestore((await list.collection('items').get()).docs.single);
    await store.updateManual(list, original.copyWith(name: 'Flour'));
    expect(await store.addUnique(list, [GroceryItem(name: 'Rice', quantity: '2 kg')]), 1);
    final renamed = (await list.collection('items').get()).docs.firstWhere((d) => d.data()['name'] == 'Flour');
    expect(renamed.data()['status'], 'used');
    expect(renamed.data()['quantity'], '1 kg');
    await expectLater(store.updateManual(list, GroceryItem.fromFirestore(renamed).copyWith(name: 'Rice')), throwsStateError);
    expect((await list.collection('items').get()).docs.length, 2);
  });

  test('initialization is stable and preserves legacy list', () async {
    final db = FakeFirebaseFirestore();
    final store = GroceryStore(db);
    final lists = db.collection('users/u/groceryLists');
    final first = await store.initialize(lists, 'Shopping');
    expect((await store.initialize(lists, 'Shopping')).id, first.id);
    expect((await lists.get()).size, 1);
    final legacy = db.collection('families/f/groceryLists');
    await legacy
        .doc('random')
        .set({'title': 'Keep', 'createdAt': DateTime(2020)});
    expect((await store.initialize(legacy, 'Shopping')).id, 'random');
  });
  test(
      'normalizes duplicate names and preserves existing quantities and status',
      () async {
    final db = FakeFirebaseFirestore();
    final store = GroceryStore(db);
    final list = await store.initialize(
        db.collection('users/u/groceryLists'), 'Shopping');
    expect(
        await store.addUnique(list, [
          GroceryItem(
              name: ' Brown  Rice ',
              quantity: '1 kg',
              status: GroceryStatus.used),
          GroceryItem(name: 'brown rice', quantity: '9 kg'),
        ]),
        1);
    expect(
        await store.addUnique(
            list, [GroceryItem(name: 'BROWN RICE', quantity: '4 kg')]),
        0);
    final data = (await list.collection('items').get()).docs.single.data();
    expect(data['quantity'], '1 kg');
    expect(data['status'], 'used');
  });
  test('legacy random-ID duplicates are detected without migrating records',
      () async {
    final db = FakeFirebaseFirestore();
    final store = GroceryStore(db);
    final list = await store.initialize(
        db.collection('users/u/groceryLists'), 'Shopping');
    await list
        .collection('items')
        .doc('legacy')
        .set(GroceryItem(name: 'Milk', quantity: '1').toFirestore());
    expect(
        await store
            .addUnique(list, [GroceryItem(name: ' milk ', quantity: '2')]),
        0);
    expect((await list.collection('items').get()).docs.single.id, 'legacy');
  });
  test('deleted list cannot acquire orphan items', () async {
    final db = FakeFirebaseFirestore();
    await expectLater(
        GroceryStore(db).addUnique(db.doc('users/u/groceryLists/gone'),
            [GroceryItem(name: 'Milk', quantity: '1')]),
        throwsStateError);
  });
}
