import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:peak_flow/features/auth/models/auth_state.dart';
import 'package:peak_flow/features/auth/providers/providers.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // 🔹 1. Listen to Firebase Auth
    final authAsync = ref.watch(authStateProvider);

    if (authAsync.isLoading) {
      return const AuthLoading();
    }

    final user = authAsync.value;
    if (user == null) return const Unauthenticated();

    final profileAsync = ref.watch(userProfileStreamProvider(user.uid));

    debugPrint('AuthController uid=${user.uid} profileAsync=$profileAsync');

    if (profileAsync.isLoading) return CheckingProfile(user);

    final profile = profileAsync.value;
    debugPrint('AuthController uid=${user.uid} profile=$profile');

    if (profile == null) return IncompleteProfile(user);

    final hasCompletedProfile = profile['hasCompletedProfile'] == true;
    debugPrint(
      'AuthController uid=${user.uid} hasCompletedProfile=$hasCompletedProfile',
    );

    if (!hasCompletedProfile) return IncompleteProfile(user);

    return Authenticated(user);
  }

  // ---------------------------------------------------------------------------
  // AUTH ACTIONS (side effects only)
  // ---------------------------------------------------------------------------

  Future<void> signIn(String email, String password) async {
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      // ❗ Do NOT set state here
      // authStateProvider will emit → build() re-runs
    } on FirebaseAuthException catch (e) {
      state = AuthError(e.message ?? 'Authentication failed');
    } catch (_) {
      state = const AuthError('Something went wrong');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      state = AuthError(e.message ?? 'Google sign-in failed');
    } catch (_) {
      state = const AuthError('Google sign-in failed');
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      state = AuthError(e.message ?? 'Sign up failed');
    } catch (_) {
      state = const AuthError('Sign up failed');
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    // Firebase emits null → build() returns Unauthenticated
  }

  /// Optional helper for local / validation errors
  void emitError(String message) {
    state = AuthError(message);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
