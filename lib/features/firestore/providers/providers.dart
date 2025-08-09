import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/firestore/repository/firestore.dart';

final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  return FirestoreRepository();
});

/// Resolves only when the user doc exists. Stays `loading` until then.
final firestoreUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // 1) Wait for auth to be restored (handles cold start)
  final user = await ref.watch(authStateChangesProvider.future);
  if (user == null) throw Exception('No authenticated user');

  final repo = ref.read(firestoreRepositoryProvider);

  // 2) Try an immediate fetch
  final doc = await repo.getData(collectionPath: 'users', docId: user.uid);
  if (doc.exists) return doc.data()!;

  // 3) If not created yet, wait for it to appear
  final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final snapshot = await docRef.snapshots().firstWhere((d) => d.exists);
  return snapshot.data()!;
});
