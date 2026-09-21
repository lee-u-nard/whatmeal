import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';

/// Wraps [FirebaseAuth] for sign-in, sign-up, Google Sign-In, and sign-out.
/// Also creates/updates the user document in Firestore on auth events.
class AuthService extends ChangeNotifier {
  AuthService() {
    _auth.authStateChanges().listen((user) {
      _firebaseUser = user;
      notifyListeners();
    });
  }

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  User? _firebaseUser;

  /// Current Firebase Auth user, or null if not authenticated.
  User? get currentUser => _firebaseUser ?? _auth.currentUser;

  /// Whether the user is currently signed in.
  bool get isAuthenticated => currentUser != null;

  /// UID of the current user, or null.
  String? get uid => currentUser?.uid;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Email / Password
  // ---------------------------------------------------------------------------

  /// Sign in with email and password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Create a new account with email and password, then create the user document.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update Firebase Auth display name
    await credential.user?.updateDisplayName(displayName);

    // Create user document in Firestore
    final user = AppUser(
      id: credential.user!.uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('users').doc(user.id).set(user.toFirestore());

    return credential;
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  /// Sign in with Google.
  ///
  /// On Web: uses [signInWithPopup] with [GoogleAuthProvider] to avoid
  /// DWDS hang and the need for a client ID in index.html.
  /// On Mobile: uses [_googleSignIn.signIn].
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential credential;

      if (kIsWeb) {
        // Web — popup flow
        final authProvider = GoogleAuthProvider();
        credential = await _auth.signInWithPopup(authProvider);
      } else {
        // Mobile — native Google Sign-In flow
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User cancelled

        final googleAuth = await googleUser.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(oauthCredential);
      }

      // Upsert user document in Firestore (for first-time Google sign-in)
      final fbUser = credential.user!;
      final userRef = _firestore.collection('users').doc(fbUser.uid);
      final snap = await userRef.get();
      if (!snap.exists) {
        final user = AppUser(
          id: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: fbUser.displayName ?? 'User',
          photoUrl: fbUser.photoURL,
          createdAt: DateTime.now(),
        );
        await userRef.set(user.toFirestore());
      }

      return credential;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  /// Sign out the current user.
  ///
  /// On Web: only calls [FirebaseAuth.signOut] since [GoogleSignIn] is not
  /// initialized on Web (avoids crash on uninitialized context).
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }
}
