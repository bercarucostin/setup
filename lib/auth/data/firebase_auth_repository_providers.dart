// auth/data/firebase_auth_repository_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_auth_repository.dart';

final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final firebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(firebaseAuthRepositoryProvider).currentUser;
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthRepositoryProvider).authStateChanges;
});
