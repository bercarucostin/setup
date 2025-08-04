import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/firestore/repository/firestore.dart';

import '../models/auth_state.dart';
import '../repository/firebase_auth.dart';

class AuthController extends Notifier<AuthState> {
  late final FirebaseAuthRepository _authRepository;
  late final FirestoreRepository _firestoreRepository;
  late final StreamSubscription<User?> _authSub;

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  @override
  AuthState build() {
    _authRepository = ref.read(firebaseAuthRepositoryProvider);
    _firestoreRepository = ref.read(firestoreRepositoryProvider);

    _authSub = _authRepository.authStateChanges.listen((user) async {
      if (user == null) {
        state = Unauthenticated();
        return;
      }

      state = AuthLoading();

      try {
        await user.getIdToken(true);

        final doc = await _firestoreRepository.getData(
          collectionPath: 'users',
          docId: user.uid,
        );

        final hasCompletedProfile =
            doc.exists && doc.data()?['hasCompletedProfile'] == true;

        state =
            hasCompletedProfile ? Authenticated(user) : IncompleteProfile(user);
      } catch (e) {
        state = AuthError(_handleFirebaseError(e));
      }
    });

    ref.onDispose(() => _authSub.cancel());

    return AuthLoading();
  }

  Future<void> signIn(String email, String password) async {
    state = AuthLoading();
    try {
      await _authRepository.signIn(email: email, password: password);
      final user = _authRepository.currentUser;
      if (user != null) {
        await user.getIdToken(true);
        state = _mapUserToState(user);
      }
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  Future<void> signUp(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _authRepository.signUp(
        email: email,
        password: password,
      );

      await user.getIdToken(true);

      final userDoc = await _firestoreRepository.getData(
        collectionPath: 'users',
        docId: user.uid,
      );

      if (!userDoc.exists) {
        await _firestoreRepository.saveData(
          collectionPath: 'users',
          docId: user.uid,
          data: {'email': user.email, 'hasCompletedProfile': false},
        );
      }

      final updatedDoc = await _firestoreRepository.getData(
        collectionPath: 'users',
        docId: user.uid,
      );

      final hasCompletedProfile =
          updatedDoc.exists &&
          updatedDoc.data()?['hasCompletedProfile'] == true;

      state =
          hasCompletedProfile ? Authenticated(user) : IncompleteProfile(user);
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final user = await _authRepository.signInWithGoogle();

      if (user == null) {
        state = Unauthenticated();
        return;
      }

      await user.getIdToken(true);

      final doc = await _firestoreRepository.getData(
        collectionPath: 'users',
        docId: user.uid,
      );

      final hasCompletedProfile =
          doc.exists && doc.data()?['hasCompletedProfile'] == true;

      state =
          hasCompletedProfile ? Authenticated(user) : IncompleteProfile(user);
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    await _authRepository.signOut();
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

  void reset() {
    state = Unauthenticated();
  }
}
