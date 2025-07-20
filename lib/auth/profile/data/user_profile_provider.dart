import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firestoreUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('No authenticated user');

  final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

  if (!doc.exists) throw Exception('User profile not found in Firestore');

  return doc.data()!;
});
