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
        _userDocSubscription?.cancel();
        _userDocSubscription = null;
        _uid = null;
        if (isInitializing) {
          isInitializing = false;
          notifyListeners();
        }
      } else {
        _uid = fbUser.uid;
        _listenToUserDocument();
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
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  String? _uid;

  bool get isAuthenticated => value != null;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Reload the current Firebase user to refresh verification status.
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final updated = _auth.currentUser;
      if (updated != null && value != null) {
        value = value!.copyWith(
          isEmailVerified: updated.emailVerified,
          name: updated.displayName ?? value!.name,
          email: updated.email ?? value!.email,
        );
        notifyListeners();
      }
    }
  }

  /// Sends email verification to the currently authenticated user.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        throw _mapAuthError(e);
      }
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final fbUser = credential.user!;
      // Ensure the user document is created/updated keyed by the Firebase UID
      await _firestore.collection('users').doc(fbUser.uid).set({
        'uid': fbUser.uid,
        'email': fbUser.email,
        'displayName': fbUser.displayName ?? email.trim().split('@')[0],
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw _mapLoginError(email.trim(), e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final fbUser = credential.user!;
      await fbUser.updateDisplayName(name.trim());

      // Send email verification link
      try {
        await fbUser.sendEmailVerification();
      } catch (e) {
        debugPrint('[AuthRepo] Email verification notice: $e');
      }

      // Store user document keyed strictly by UID
      await _firestore.collection('users').doc(fbUser.uid).set({
        'uid': fbUser.uid,
        'email': fbUser.email,
        'displayName': name.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  void _listenToUserDocument() {
    _userDocSubscription?.cancel();
    if (_uid == null) return;

    _userDocSubscription = _firestore
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen((snapshot) {
      final fbUser = _auth.currentUser;
      if (fbUser == null) return;

      if (snapshot.exists) {
        final data = snapshot.data()!;
        value = UserModel(
          id: fbUser.uid,
          name: data['displayName'] ?? fbUser.displayName ?? 'User',
          email: data['email'] ?? fbUser.email ?? '',
          familySpaceId: data['familyId'] ?? data['familySpaceId'],
          avatarUrl: data['photoUrl'],
          isEmailVerified: fbUser.emailVerified,
        );
      } else {
        value = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? 'User',
          email: fbUser.email ?? '',
          isEmailVerified: fbUser.emailVerified,
        );
      }
    }, onError: (error) {
      debugPrint('[AuthRepo] User document listener error: $error');
      // On error, still provide basic user info from FirebaseAuth
      final fbUser = _auth.currentUser;
      if (fbUser != null) {
        value = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? 'User',
          email: fbUser.email ?? '',
          isEmailVerified: fbUser.emailVerified,
        );
      }
    });
  }

  Future<void> updateProfile({
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      // Update Firebase Auth display name
      await user.updateDisplayName(displayName);

      // Update Firestore document
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // The real-time listener will update the UI automatically
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      // Reauthenticate with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // Password is NOT stored in Firestore - only in Firebase Auth
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Current password is incorrect');
      } else if (e.code == 'weak-password') {
        throw Exception('New password is too weak');
      } else if (e.code == 'requires-recent-login') {
        throw Exception('Please log in again before changing your password');
      }
      throw _mapAuthError(e);
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Distinguishes wrong email/username vs wrong password when possible.
  String _mapLoginError(String email, FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account was found with that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please check your password and try again.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password. Please check your credentials and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a moment and try again.';
      case 'invalid-email':
        return 'The email format is invalid. Please enter a valid email address.';
      default:
        return _mapAuthError(e);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account was found with that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please check your password and try again.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password. Please check your credentials and try again.';
      case 'email-already-in-use':
        return 'This email address is already registered. Please sign in instead.';
      case 'weak-password':
        return 'The password provided is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'The email format is invalid. Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      default:
        return e.message ??
            'An authentication error occurred. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
