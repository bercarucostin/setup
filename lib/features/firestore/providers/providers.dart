import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/firestore/repository/firestore.dart';

final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  return FirestoreRepository();
});

/// Provides the Firestore user profile data.
/// It fetches the user profile from Firestore based on the current authenticated user.
/// If the user is not authenticated or the profile does not exist, it throws an exception.
final firestoreUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('No authenticated user');

  final firestoreRepo = ref.read(firestoreRepositoryProvider);
  final doc = await firestoreRepo.getData(
    collectionPath: 'users',
    docId: user.uid,
  );

  if (!doc.exists) throw Exception('User profile not found in Firestore');

  return doc.data()!;
});
