import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/pantry/data/pantry_repository.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';
import 'package:whatmeal/features/profile/data/family_member_repository.dart';
import 'package:whatmeal/features/profile/models/family_member.dart';

FamilySpace home(String uid) =>
    FamilySpace(id: 'home-$uid', name: uid, inviteCode: '', members: [
      SharedSpaceMember(id: uid, name: uid, email: '', role: FamilyRole.owner)
    ]);

void main() {
  for (final pantry in [true, false]) {
    final label = pantry ? 'pantry' : 'dietary profiles';
    test(
        '$label reopens a terminal feed and ignores first A session after A B A',
        () async {
      final ids = StreamController<String?>.broadcast(sync: true);
      final household = ValueNotifier<FamilySpace?>(null);
      final db = FakeFirebaseFirestore();
      final paths = <String>[];
      final ps = <StreamController<List<PantryItem>>>[];
      final fs = <StreamController<List<FamilyMember>>>[];
      final p = pantry
          ? PantryRepository(
              firestore: db,
              authIds: ids.stream,
              household: household,
              watch: (path) {
                paths.add(path);
                final c =
                    StreamController<List<PantryItem>>.broadcast(sync: true);
                ps.add(c);
                return c.stream;
              })
          : null;
      final f = pantry
          ? null
          : FamilyMemberRepository(
              firestore: db,
              authIds: ids.stream,
              household: household,
              watch: (path) {
                paths.add(path);
                final c =
                    StreamController<List<FamilyMember>>.broadcast(sync: true);
                fs.add(c);
                return c.stream;
              });
      void emit(String name) {
        if (pantry) {
          ps.last.add([PantryItem(name: name, quantity: '1')]);
        } else {
          fs.last.add([
            FamilyMember(name: name, age: 10, preferences: [], restrictions: [])
          ]);
        }
      }

      List<String> names() => pantry
          ? p!.value.values.expand((v) => v).map((i) => i.name).toList()
          : f!.value.map((i) => i.name).toList();
      ids.add('a');
      emit('first A');
      if (pantry) {
        ps.last.addError(StateError('private'));
        await ps.last.close();
      } else {
        fs.last.addError(StateError('private'));
        await fs.last.close();
      }
      expect(names(), isEmpty);
      expect(p?.error ?? f?.error, isNotNull);
      p?.retry();
      f?.retry();
      expect(paths.length, 2,
          reason: 'Retry must create a new subscription after terminal close');
      emit('recovered A');
      expect(names(), ['recovered A']);
      ids.add('b');
      expect(names(), isEmpty);
      emit('B');
      expect(names(), ['B']);
      ids.add('a');
      expect(names(), isEmpty);
      emit('new A');
      expect(names(), ['new A']);
      if (pantry) {
        ps[1].add([PantryItem(name: 'late first A', quantity: '9')]);
        ps[2].addError(StateError('late B'));
      } else {
        fs[1].add([
          const FamilyMember(
              name: 'late first A', age: 1, preferences: [], restrictions: [])
        ]);
        fs[2].addError(StateError('late B'));
      }
      expect(names(), ['new A']);
      expect(p?.error ?? f?.error, isNull);
      expect(paths, [
        'users/a/${pantry ? 'pantryItems' : 'familyMembers'}',
        'users/a/${pantry ? 'pantryItems' : 'familyMembers'}',
        'users/b/${pantry ? 'pantryItems' : 'familyMembers'}',
        'users/a/${pantry ? 'pantryItems' : 'familyMembers'}'
      ]);
      p?.dispose();
      f?.dispose();
      final count = paths.length;
      ids.add('b');
      household.value = home('b');
      expect(paths.length, count,
          reason: 'Disposed repositories must detach both sources');
      household.dispose();
      await ids.close();
      for (final c in ps) {
        await c.close();
      }
      for (final c in fs) {
        await c.close();
      }
    });
    test(
        '$label publishes the new scope atomically during rapid account switches',
        () async {
      final ids = StreamController<String?>.broadcast(sync: true);
      final household = ValueNotifier<FamilySpace?>(home('a'));
      final db = FakeFirebaseFirestore();
      final p = pantry
          ? PantryRepository(
              firestore: db,
              authIds: ids.stream,
              household: household,
              watch: (_) => const Stream.empty())
          : null;
      final f = pantry
          ? null
          : FamilyMemberRepository(
              firestore: db,
              authIds: ids.stream,
              household: household,
              watch: (_) => const Stream.empty());
      final Listenable repo = p ?? f!;
      String? scope() => p?.scopePath ?? f?.scopePath;
      ids.add('a');
      expect(scope(), 'families/home-a');
      final published = <String?>[];
      repo.addListener(() => published.add(scope()));
      ids.add(
          'b'); // Household still carries A while its own listener catches up.
      expect(published, ['users/b']);
      household.value = home('b');
      expect(scope(), 'families/home-b');
      ids.add(null);
      ids.add('a');
      expect(scope(), 'users/a');
      household.value = home('a');
      expect(scope(), 'families/home-a');
      p?.dispose();
      f?.dispose();
      household.dispose();
      await ids.close();
    });

    test('$label publishes a safe failure before notifying observers',
        () async {
      final ids = StreamController<String?>.broadcast(sync: true);
      final household = ValueNotifier<FamilySpace?>(null);
      final pc = StreamController<List<PantryItem>>.broadcast(sync: true);
      final fc = StreamController<List<FamilyMember>>.broadcast(sync: true);
      final db = FakeFirebaseFirestore();
      final p = pantry
          ? PantryRepository(
              firestore: db,
              authIds: ids.stream,
              household: household,
              watch: (_) => pc.stream)
          : null;
      final f = pantry
          ? null
          : FamilyMemberRepository(
              firestore: db,
              authIds: ids.stream,
              household: household,
              watch: (_) => fc.stream);
      ids.add('a');
      pc.add([PantryItem(name: 'A', quantity: '1')]);
      fc.add([
        const FamilyMember(
            name: 'A', age: 10, preferences: [], restrictions: [])
      ]);
      final errors = <String?>[];
      (p ?? f!).addListener(() => errors.add(p?.error ?? f?.error));
      if (pantry) {
        pc.addError(StateError('private diagnostic'));
      } else {
        fc.addError(StateError('private diagnostic'));
      }
      expect(errors, isNotEmpty);
      expect(
          errors.every((e) => e != null && !e.contains('private diagnostic')),
          isTrue);
      p?.dispose();
      f?.dispose();
      household.dispose();
      await ids.close();
      await pc.close();
      await fc.close();
    });
  }
}
