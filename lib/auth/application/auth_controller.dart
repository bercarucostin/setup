import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_state.dart';
import '../data/firebase_auth_repository.dart';

final firebaseAuthRepositoryProvider = Provider(
  (ref) => FirebaseAuthRepository(),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);

class AuthController extends Notifier<AuthState> {
  late final FirebaseAuthRepository _authRepository;
  late final StreamSubscription<User?> _authSub;

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  @override
  AuthState build() {
    _authRepository = ref.read(firebaseAuthRepositoryProvider);

    // Listen to auth state changes and map to app states
    _authSub = _authRepository.authStateChanges.listen((user) async {
      if (user == null) {
        state = Unauthenticated();
        return;
      }

      state = AuthLoading();

      // Ensure the user token is refreshed before accessing Firestore
      await user.getIdToken(true);

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final hasCompletedProfile =
          doc.exists && doc.data()?['hasCompletedProfile'] == true;

      if (hasCompletedProfile) {
        state = Authenticated(user);
      } else {
        state = IncompleteProfile(user);
      }
    });

    // Cancel stream when provider is disposed
    ref.onDispose(() {
      _authSub.cancel();
    });

    return AuthLoading();
  }

  Future<void> signIn(String email, String password) async {
    state = AuthLoading();
    try {
      await _authRepository.signIn(email: email, password: password);
      final user = _authRepository.currentUser;
      if (user != null) {
        await user.getIdToken(true); // ensure token is ready
        state = _mapUserToState(user);
      }
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  Future<void> signUp(String email, String password) async {
    final user = await _authRepository.signUp(email: email, password: password);

    // Refresh token to ensure Firestore uses a valid token
    await user.getIdToken(true);

    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    // Ensure the document exists
    final snapshot = await userDoc.get();
    if (!snapshot.exists) {
      await userDoc.set({
        'email': user.email,
        'hasCompletedProfile': false,
      }, SetOptions(merge: true));
    }

    // Now safely check the document
    final updatedDoc = await userDoc.get();
    final hasCompletedProfile =
        updatedDoc.exists && updatedDoc.data()?['hasCompletedProfile'] == true;

    if (hasCompletedProfile) {
      state = Authenticated(user);
    } else {
      state = IncompleteProfile(user);
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    await _authRepository.signOut();
  }

  Future<void> signInWithGoogle() async {
    final user = await _authRepository.signInWithGoogle();
    if (user == null) {
      state = Unauthenticated();
      return;
    }

    await user.getIdToken(true);

    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final hasCompletedProfile =
        doc.exists && doc.data()?['hasCompletedProfile'] == true;

    if (hasCompletedProfile) {
      state = Authenticated(user);
    } else {
      state = IncompleteProfile(user);
    }
  }

  Stream<AuthState> get stream =>
      _authRepository.authStateChanges.map(_mapUserToState);

  AuthState _mapUserToState(User? user) {
    if (user == null) return Unauthenticated();
    return (user.displayName == null || user.displayName!.isEmpty)
        ? IncompleteProfile(user)
        : Authenticated(user);
  }

  String _handleFirebaseError(Object error) {
    return error is FirebaseAuthException
        ? error.message ?? 'Unknown Firebase error'
        : error.toString();
  }
}
