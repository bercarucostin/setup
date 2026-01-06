// INIT FIREBASE AUTH PROVIDER
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_flow/features/firestore/repository/firestore.dart';

final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  return FirestoreRepository();
});
