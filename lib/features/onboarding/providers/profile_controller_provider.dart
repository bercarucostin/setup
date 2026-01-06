import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_flow/features/firestore/providers/providers.dart';
import 'package:peak_flow/features/onboarding/providers/onboarding_notifier_provider.dart';

import '../../auth/providers/providers.dart';

class ProfileSetupController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> completeProfile() async {
    final draft = ref.read(onboardingDraftProvider);

    if (!draft.isComplete) {
      throw StateError('Onboarding is not complete');
    }

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(firestoreRepositoryProvider)
          .saveData(
            collectionPath: 'users',
            docId: user.uid,
            data: {
              ...draft.toFirestoreMap(user.email ?? ''),
              'hasCompletedProfile': true,
            },
            merge: true,
          );
    });

    // ✅ Clear draft after successful commit
    ref.invalidate(onboardingDraftProvider);
  }
}

final profileSetupControllerProvider =
    NotifierProvider<ProfileSetupController, AsyncValue<void>>(
      ProfileSetupController.new,
    );
