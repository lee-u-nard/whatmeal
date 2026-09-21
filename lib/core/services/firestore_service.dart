import 'package:cloud_firestore/cloud_firestore.dart';

/// Central Firestore service providing collection references and database configuration.
class FirestoreService {
  FirestoreService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  /// Enable offline persistence with cache settings.
  Future<void> enablePersistence() async {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// Reference to the `users` collection.
  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _firestore.collection('users');

  /// Reference to the `families` collection.
  CollectionReference<Map<String, dynamic>> get familiesCollection =>
      _firestore.collection('families');

  /// Helper for subcollections under a specific family.
  CollectionReference<Map<String, dynamic>> familySubcollection(
    String familyId,
    String subcollection,
  ) =>
      _firestore
          .collection('families')
          .doc(familyId)
          .collection(subcollection);
}
