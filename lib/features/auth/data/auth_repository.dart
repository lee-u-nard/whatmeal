import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/account_action_failure.dart';
import '../../../core/services/secure_key_store.dart';
import '../../../core/services/notification_service.dart';

class AuthRepository extends ValueNotifier<UserModel?> {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String)?
        watchProfile,
    Future<void> Function()? cleanupNotifications,
    Future<void> Function(String)? clearKey,
  })  : _auth = auth,
        _firestore = firestore,
        _watchProfile = watchProfile,
        _cleanupNotifications = cleanupNotifications,
        _clearKey = clearKey,
        super(null) {
    _authSubscription = _auth.authStateChanges().listen((fbUser) async {
      if (_disposed) return;
      ++_session;
      ++_profileEpoch;
      profileError = null;
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
        if (_uid != fbUser.uid) value = null;
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

  static final instance = AuthRepository(
      auth: FirebaseAuth.instance, firestore: FirebaseFirestore.instance);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String)?
      _watchProfile;
  final Future<void> Function()? _cleanupNotifications;
  final Future<void> Function(String)? _clearKey;
  bool _disposed = false;
  int _profileEpoch = 0;
  String? profileError;
  void retryProfile() {
    if (_disposed || _uid == null) return;
    profileError = null;
    _listenToUserDocument();
    notifyListeners();
  }

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  String? _uid;
  int _session = 0;

  int get sessionVersion => _session;
  bool get isAuthenticated => value != null;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Reload the current Firebase user to refresh verification status.
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    final session = _session;
    if (user != null) {
      await user.reload();
      if (session != _session) return;
      final updated = _auth.currentUser;
      if (updated != null && value != null) {
        value = value!.copyWith(
          isEmailVerified: updated.emailVerified,
          name: value!.name,
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
      final ref = _firestore.collection('users').doc(fbUser.uid);
      await _firestore.runTransaction((tx) async {
        final existing = await tx.get(ref);
        tx.set(
            ref,
            {
              'uid': fbUser.uid,
              'email': fbUser.email,
              if (!existing.exists)
                'displayName': fbUser.displayName ?? email.trim().split('@')[0],
              'lastLoginAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });
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
        debugPrint('[AuthRepo] Email verification failed (${e.runtimeType})');
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
    final user = _auth.currentUser;
    final session = _session;
    await (_cleanupNotifications?.call() ??
        NotificationService.instance.cleanupOnLogout());
    if (user != null) {
      _requireSession(user, session);
    } else if (_auth.currentUser != null || _session != session) {
      throw const AccountActionFailure(AccountFailureKind.sessionChanged);
    }
    await _auth.signOut();
    if (_auth.currentUser != null) {
      throw const AccountActionFailure(AccountFailureKind.sessionChanged);
    }
    if (user != null) {
      await (_clearKey?.call(user.uid) ??
          SecureKeyStore.instance.clearApiKey(user.uid));
    }
  }

  void _listenToUserDocument() {
    _userDocSubscription?.cancel();
    if (_uid == null) return;
    final listeningUid = _uid;
    final session = _session;
    final epoch = ++_profileEpoch;
    _userDocSubscription = (_watchProfile?.call(listeningUid!) ??
            _firestore.collection('users').doc(listeningUid).snapshots())
        .listen((snapshot) {
      final fbUser = _auth.currentUser;
      if (_disposed ||
          epoch != _profileEpoch ||
          session != _session ||
          fbUser == null ||
          fbUser.uid != listeningUid) {
        return;
      }

      profileError = null;
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
      if (_disposed ||
          epoch != _profileEpoch ||
          session != _session ||
          _auth.currentUser?.uid != listeningUid) {
        return;
      }
      debugPrint('[AuthRepo] Profile listener failed (${error.runtimeType})');
      profileError = 'Account profile could not be loaded. Please retry.';
      // Keep Auth identity usable while exposing failed canonical profile loading.
      final fbUser = _auth.currentUser;
      if (fbUser != null) {
        value = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? 'User',
          email: fbUser.email ?? '',
          isEmailVerified: fbUser.emailVerified,
        );
      }
    }, cancelOnError: true);
  }

  void _requireSession(User user, int session) {
    if (_disposed ||
        _session != session ||
        _auth.currentUser?.uid != user.uid) {
      throw const AccountActionFailure(AccountFailureKind.sessionChanged);
    }
  }

  Future<void> updateProfile({required String displayName}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountActionFailure(AccountFailureKind.signedOut);
    }
    final session = _session;
    final name = displayName.trim();
    if (name.isEmpty || name.length > 120) {
      throw const AccountActionFailure(AccountFailureKind.invalidName);
    }
    var saved = false;
    try {
      _requireSession(user, session);
      // The profile document is the existing UI authority. Login preserves it.
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      saved = true;
      _requireSession(user, session);
      await user.updateDisplayName(name);
      _requireSession(user, session);
    } on AccountActionFailure {
      rethrow;
    } catch (_) {
      throw AccountActionFailure(saved
          ? AccountFailureKind.profileSync
          : AccountFailureKind.unavailable);
    }
  }

  Future<void> updatePassword(
      {required String currentPassword, required String newPassword}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountActionFailure(AccountFailureKind.signedOut);
    }
    final session = _session;
    if (user.email == null ||
        !user.providerData.any((p) => p.providerId == 'password')) {
      throw const AccountActionFailure(AccountFailureKind.passwordProvider);
    }
    try {
      _requireSession(user, session);
      final credential = EmailAuthProvider.credential(
          email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      _requireSession(user, session);
      await user.updatePassword(newPassword);
      _requireSession(user, session);
      // Passwords are handled exclusively by Firebase Auth, never Firestore.
    } on AccountActionFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AccountActionFailure.forCode(e.code);
    } catch (_) {
      throw const AccountActionFailure(AccountFailureKind.unavailable);
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
        return 'An authentication error occurred. Please try again.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_session;
    ++_profileEpoch;
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
