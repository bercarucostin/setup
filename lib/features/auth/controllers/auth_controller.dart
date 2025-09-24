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
  late final FirestoreRepository _firestore;

  @override
  AuthState build() {
    _authRepository = ref.read(firebaseAuthRepositoryProvider);
    _firestore = ref.read(firestoreRepositoryProvider);

    // Listen to the repo's stream via the StreamProvider (no manual subscription)
    ref.listen<AsyncValue<User?>>(authStateChangesProvider, (prev, next) async {
      final user = next.valueOrNull;

      if (user == null) {
        state = Unauthenticated();
        return;
      }

      state = AuthLoading();
      try {
        final completed = await _hasCompletedProfile(user.uid);

        // stale-guard: ignore if auth changed while we were awaiting
        if (_authRepository.currentUser?.uid != user.uid) return;

        state = completed ? Authenticated(user) : IncompleteProfile(user);
      } catch (e) {
        if (_authRepository.currentUser?.uid != user.uid) return;
        state = AuthError(_handleFirebaseError(e));
      }
    });

    // Initial snapshot until Firestore check completes
    final u = _authRepository.currentUser;
    return u == null ? Unauthenticated() : AuthLoading();
  }

  Future<bool> _hasCompletedProfile(String uid) async {
    final doc = await _firestore.getData(collectionPath: 'users', docId: uid);
    final data = doc.data();
    return doc.exists && (data?['hasCompletedProfile'] == true);
  }

  Future<void> signIn(String email, String password) async {
    state = AuthLoading();
    try {
      await _authRepository.signIn(email: email, password: password);
      // Listener will set Authenticated/IncompleteProfile
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
      // Ensure user doc exists (idempotent)
      await _firestore.saveData(
        collectionPath: 'users',
        docId: user.uid,
        data: {'email': user.email, 'hasCompletedProfile': false},
        merge: true,
      );
      // Listener will pick up and decide next state
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthLoading();
    try {
      final user = await _authRepository.signInWithGoogle();
      if (user == null) {
        state = Unauthenticated();
        return;
      }
      // Listener handles Firestore check
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  Future<void> markProfileCompleted() async {
    final user = _authRepository.currentUser;
    if (user == null) throw Exception('No signed-in user');

    await _firestore.saveData(
      collectionPath: 'users',
      docId: user.uid,
      data: {'hasCompletedProfile': true},
      merge: true,
    );

    // Optional eager update (listener will confirm anyway)
    state = Authenticated(user);
  }

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
      // Listener emits Unauthenticated
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  String _handleFirebaseError(Object error) {
    return error is FirebaseAuthException
        ? (error.message ?? 'Unknown Firebase error')
        : error.toString();
  }
}
