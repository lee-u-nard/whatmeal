import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthRepository extends ValueNotifier<UserModel?> {
  AuthRepository._() : super(null) {
    _authSubscription = _auth.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        value = null;
        if (isInitializing) {
          isInitializing = false;
          notifyListeners();
        }
      } else {
        // Ensure doc exists, wait for network if possible, but optimistic local update
        try {
          final doc = await _firestore.collection('users').doc(fbUser.uid).get();
          if (doc.exists) {
            final data = doc.data()!;
            value = UserModel(
              id: fbUser.uid,
              name: data['displayName'] ?? fbUser.displayName ?? 'User',
              email: data['email'] ?? fbUser.email ?? '',
              familySpaceId: data['familySpaceId'],
              avatarUrl: data['photoUrl'],
            );
          } else {
            value = UserModel(
              id: fbUser.uid,
              name: fbUser.displayName ?? 'User',
              email: fbUser.email ?? '',
            );
          }
        } catch (_) {
          // If offline, still provide basic user info
          value = UserModel(
            id: fbUser.uid,
            name: fbUser.displayName ?? 'User',
            email: fbUser.email ?? '',
          );
        }
        if (isInitializing) {
          isInitializing = false;
          notifyListeners();
        }
      }
    });
  }

  bool isInitializing = true;

  static final instance = AuthRepository._();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;

  bool get isAuthenticated => value != null;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final fbUser = credential.user!;
      await _firestore.collection('users').doc(fbUser.uid).set({
        'uid': fbUser.uid,
        'email': fbUser.email,
        'displayName': fbUser.displayName ?? email.split('@')[0],
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await credential.user?.updateDisplayName(name);
      
      final fbUser = credential.user!;
      await _firestore.collection('users').doc(fbUser.uid).set({
        'uid': fbUser.uid,
        'email': fbUser.email,
        'displayName': name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      default:
        return e.message ?? 'An unknown authentication error occurred.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
