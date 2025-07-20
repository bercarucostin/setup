import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:setup/auth/application/auth_controller.dart';
import 'package:setup/auth/domain/auth_state.dart';
import '../domain/profile_setup_data.dart';

final profileSetupProvider =
    NotifierProvider<ProfileSetupNotifier, ProfileSetupData>(
      () => ProfileSetupNotifier(),
    );

class ProfileSetupNotifier extends Notifier<ProfileSetupData> {
  @override
  ProfileSetupData build() => const ProfileSetupData();

  void updateNameAndBirthday(String name, String birthday) {
    state = state.copyWith(fullName: name, birthday: birthday);
  }

  void updateChronotype(String value) {
    state = state.copyWith(chronotype: value);
  }

  void updateSleepTimes(String wake, String bed) {
    state = state.copyWith(wakeTime: wake, bedTime: bed);
  }

  void updateGoal(String value) {
    state = state.copyWith(goal: value);
  }

  Future<void> submitAndSaveToFirestore(WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No signed-in user');

    final data = state.toFirestoreMap(user.email ?? '');

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      ...data,
      'hasCompletedProfile': true,
    }, SetOptions(merge: true));

    // Update Firebase displayName if needed
    if (state.fullName != null) {
      await user.updateDisplayName(state.fullName);
      await user.reload();
    }

    // Switch app state to authenticated
    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser != null) {
      ref.read(authControllerProvider.notifier).state = Authenticated(
        refreshedUser,
      );
    }
  }
}
