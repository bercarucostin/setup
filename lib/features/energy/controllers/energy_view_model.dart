// lib/features/energy/energy_view_model.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/energy/repository/energy_repository.dart';

/// Provides the Firestore-backed EnergyRepository
final energyRepositoryProvider = Provider<EnergyRepository>((ref) {
  final firestoreRepo = ref.read(firestoreRepositoryProvider);
  return EnergyRepository(firestoreRepo);
});

/// AsyncNotifierProvider managing load, refresh, and update of EnergyModel
// final energyModelProvider =
//     AsyncNotifierProvider<EnergyModelNotifier, EnergyModel?>(
//       EnergyModelNotifier.new,
//     );

class EnergyModelNotifier extends AsyncNotifier<EnergyModel?> {
  @override
  Future<EnergyModel?> build() async {
    final user = await ref.watch(signedInUserProvider.future);
    // Fetch authenticated user info
    final snap = await ref.watch(userProfileDocProvider.future);
    final profile =
        (snap != null && snap.exists) ? snap.data()! : <String, dynamic>{};
    // 3) Read fields needed to choose/fetch the model
    final chronotype = (profile['chronotype'] as String);

    // 4) Load user-specific model or fallback
    final repo = ref.read(energyRepositoryProvider);
    return await repo.fetchUserEnergyModel(profile, user.uid) ??
        await repo.fetchDefaultEnergyModel(chronotype, profile, user.uid);
  }

  /// Explicit refresh of the EnergyModel
  Future<void> refreshModel() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Persist updated energy measurement back to Firestore
  Future<void> updateModelWeights({
    required int hour,
    required double actualEnergy,
  }) async {
    final model = state.value;
    final user = ref.read(firebaseUserProvider);
    if (model == null || user == null) {
      throw StateError('No model loaded to update');
    }

    // Update in memory
    model.updateWeights(hour, actualEnergy, user.uid);

    // Save whole model
    final repo = ref.read(energyRepositoryProvider);
    await repo.saveEnergyModel(user.uid, model);

    // Emit updated model
    state = AsyncData(model);
  }

  /// Persist updated energy measurement back to Firestore
  Future<void> updateHoursSlept({required int hoursSlept}) async {
    final model = state.value;
    final user = ref.read(firebaseUserProvider);
    if (model == null || user == null) {
      throw StateError('No model loaded to update');
    }

    // Update in memory
    model.updateHoursSlept(hoursSlept);

    // Save whole model
    final repo = ref.read(energyRepositoryProvider);
    await repo.saveEnergyModel(user.uid, model);

    // Emit updated model
    state = AsyncData(model);
  }

  Future<void> deleteModel(String userId) async {
    final repo = ref.read(energyRepositoryProvider);
    await repo.deleteEnergyModel(userId);

    // Clear local model
    state = const AsyncData(null);
  }
}
