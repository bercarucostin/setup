import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:setup/features/auth/models/auth_state.dart';
import 'package:setup/features/auth/models/user.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/firestore/providers/providers.dart';

class ProfileSetupNotifier extends Notifier<UserData> {
  @override
  UserData build() => const UserData();

  void updateNameAndBirthday(String name, String birthday) {
    state = state.copyWith(fullName: name, birthday: birthday);
  }

  void updateChronotype(String value) {
    state = state.copyWith(chronotype: value);
  }

  void updateSleepTimes(String wake, String bed, int wakeHour, int bedHour) {
    state = state.copyWith(
      wakeTime: wake,
      bedTime: bed,
      wakeHour: wakeHour,
      bedHour: bedHour,
    );
  }

  void updateGoal(String value) {
    state = state.copyWith(goal: value);
  }

  Future<void> submitAndSaveToFirestore(WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No signed-in user');

    // Prepare the data
    final data = state.toFirestoreMap(user.email ?? '');
    final firestoreRepo = ref.read(firestoreRepositoryProvider);

    // Use repository to save the user document
    await firestoreRepo.saveData(
      collectionPath: 'users',
      docId: user.uid,
      data: {...data, 'hasCompletedProfile': true},
      merge: true,
    );

    // Update FirebaseAuth displayName
    if (state.fullName != null) {
      await user.updateDisplayName(state.fullName);
      await user.reload();
    }

    // Refresh and update app auth state
    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser != null) {
      ref.read(authControllerProvider.notifier).state = Authenticated(
        refreshedUser,
      );
    }
  }

  Future<void> savePartial(WidgetRef ref, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No signed-in user');

    final repo = ref.read(firestoreRepositoryProvider);
    // Only update the provided keys — everything else stays untouched.
    await repo.saveData(
      collectionPath: 'users',
      docId: user.uid,
      data: data,
      merge: true,
    );
  }
}
