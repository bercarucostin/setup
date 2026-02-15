import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Watt/features/auth/repositories/auth_repository.dart';
import 'package:Watt/features/firestore/providers/providers.dart';

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

class AccountDeletionFlag extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;
  void stop() => state = false;
}

final accountDeletionInProgressProvider =
    NotifierProvider<AccountDeletionFlag, bool>(AccountDeletionFlag.new);
