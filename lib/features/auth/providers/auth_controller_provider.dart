import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:watt/features/auth/models/auth_state.dart';
import 'package:watt/features/auth/providers/providers.dart';
import 'package:watt/features/firestore/providers/providers.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final isDeleting = ref.watch(accountDeletionInProgressProvider);
    if (isDeleting) return const AuthLoading();
    // 🔹 1. Listen to Firebase Auth
    final authAsync = ref.watch(authStateProvider);

    if (authAsync.isLoading) {
      return const AuthLoading();
    }

    final user = authAsync.value;
    if (user == null) return const Unauthenticated();

    final profileAsync = ref.watch(userProfileStreamProvider(user.uid));

    //debugPrint('AuthController uid=${user.uid} profileAsync=$profileAsync');

    if (profileAsync.isLoading) return CheckingProfile(user);

    final profile = profileAsync.value;
    //debugPrint('AuthController uid=${user.uid} profile=$profile');

    if (profile == null) return IncompleteProfile(user);

    final hasCompletedProfile = profile['hasCompletedProfile'] == true;
    // debugPrint(
    //   'AuthController uid=${user.uid} hasCompletedProfile=$hasCompletedProfile',
    // );

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

  Future<void> signInWithApple() async {
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
    } on FirebaseAuthException catch (e) {
      state = AuthError(e.message ?? 'Apple sign-in failed');
    } catch (_) {
      state = const AuthError('Apple sign-in failed');
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

  Future<void> deleteAccount({
    String? password, // required for email/password users
  }) async {
    // Show overlay (your UI treats AuthLoading as busy)
    ref.read(accountDeletionInProgressProvider.notifier).start();

    state = const AuthLoading();

    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        state = const AuthError('Not signed in.');
        return;
      }

      // 1) Re-authenticate first (avoid requires-recent-login later)
      final providerIds = user.providerData.map((p) => p.providerId).toSet();

      if (providerIds.contains('password')) {
        if (password == null || password.trim().isEmpty) {
          state = const AuthError('Please enter your password to delete.');
          return;
        }
        final email = user.email;
        if (email == null || email.isEmpty) {
          state = const AuthError('Missing email for password re-auth.');
          return;
        }
        await ref
            .read(authRepositoryProvider)
            .reauthenticateWithPassword(
              email: email,
              password: password.trim(),
            );
      } else if (providerIds.contains('google.com')) {
        await ref.read(authRepositoryProvider).reauthenticateWithGoogle();
      } else if (providerIds.contains('apple.com')) {
        await ref.read(authRepositoryProvider).reauthenticateWithApple();
      } else {
        state = AuthError('Unsupported sign-in method: $providerIds');
        return;
      }

      // 2) Delete user data in Firestore (your app-specific cleanup)
      await ref.read(firestoreRepositoryProvider).deleteUserData(user.uid);

      // 3) Delete Firebase Auth user
      await ref.read(authRepositoryProvider).deleteCurrentUser();

      // 4) Optional: sign out (safe; won't block success if it fails)
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (_) {}

      // Don’t set state here; authStateProvider will emit null and build() returns Unauthenticated
    } on FirebaseAuthException catch (e) {
      state = AuthError(e.message ?? 'Delete account failed');
    } catch (_) {
      state = const AuthError('Delete account failed');
    } finally {
      ref.read(accountDeletionInProgressProvider.notifier).stop();
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
