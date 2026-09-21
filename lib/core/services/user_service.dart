import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Service for reading/writing user documents at `users/{uid}`.
class UserService {
  UserService();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  /// Stream the current user's [AppUser] document.
  Stream<AppUser?> userStream(String uid) {
    return _usersCol.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUser.fromFirestore(snap);
    });
  }

  /// Fetch user document once.
  Future<AppUser?> getUser(String uid) async {
    final snap = await _usersCol.doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromFirestore(snap);
  }

  /// Update specific fields on the user document.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _usersCol.doc(uid).update(data);
  }

  /// Set the user's active family ID.
  Future<void> setFamilyId(String uid, String? familyId) async {
    await _usersCol.doc(uid).update({'familyId': familyId});
  }
}
