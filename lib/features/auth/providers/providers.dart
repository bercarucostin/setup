import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_flow/features/auth/repositories/auth_repository.dart';
import 'package:peak_flow/features/firestore/providers/providers.dart';

// INIT FIREBASE AUTH PROVIDER
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// AUTH STATE PROVIDER used to listen to auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// AUTH REPOSITORY PROVIDER used to access AuthRepository methods
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

final userProfileStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, uid) {
      return ref
          .read(firestoreRepositoryProvider)
          .watchDocument(collectionPath: 'users', docId: uid);
    });
