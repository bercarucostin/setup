import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/auth/controllers/profile_setup_notifier.dart';
import 'package:setup/features/auth/controllers/auth_controller.dart';
import 'package:setup/features/auth/models/auth_state.dart';
import 'package:setup/features/auth/models/user.dart';
import 'package:setup/features/auth/repository/firebase_auth.dart';
import 'package:setup/features/firestore/providers/providers.dart';

/// Provides the FirebaseAuthRepository instance.
/// This repository handles authentication operations like sign-in, sign-out, etc.
final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  return FirebaseAuthRepository();
});

/// Provides the current Firebase user.
/// This is useful for accessing user details in the UI or other providers.
final firebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(firebaseAuthRepositoryProvider).currentUser;
});

/// Provides the current authentication state changes as a stream.
/// This is useful for listening to auth state changes in the UI.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthRepositoryProvider).authStateChanges;
});

/// Provides the current authentication state.
/// It uses the [AuthController] to manage the state.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);

/// Provides the profile setup notifier.
/// This notifier manages the profile setup data and operations.
/// It allows updating user profile information like name, birthday, chronotype, etc.
/// It also handles saving the profile data to Firestore.
final profileSetupProvider = NotifierProvider<ProfileSetupNotifier, UserData>(
  () => ProfileSetupNotifier(),
);

final userProfileDocProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
      final auth = ref.watch(authStateChangesProvider);
      return auth.when(
        loading: () => const Stream.empty(),
        error: (_, __) => const Stream.empty(),
        data: (user) {
          if (user == null) return const Stream.empty();
          return FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();
        },
      );
    });

final signedInUserProvider = FutureProvider.autoDispose<User>((ref) async {
  // Tie this provider to auth updates so it recomputes on sign-in/sign-out.
  ref.watch(authStateChangesProvider);
  ref.watch(profileSetupProvider);

  // Wait for the first non-null user from Firebase.
  final repo = ref.read(firebaseAuthRepositoryProvider);
  return await repo.authStateChanges
      .where((u) => u != null)
      .map((u) => u!) // safe due to predicate
      .first; // completes when a user is available
});
