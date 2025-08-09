// lib/features/energy/energy_view_model.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/energy/repository/repository.dart';

/// Provides the Firestore-backed EnergyRepository
final energyRepositoryProvider = Provider<EnergyRepository>((ref) {
  final firestoreRepo = ref.read(firestoreRepositoryProvider);
  return EnergyRepository(firestoreRepo);
});

/// AsyncNotifierProvider managing load, refresh, and update of EnergyModel
final energyModelProvider =
    AsyncNotifierProvider<EnergyModelNotifier, EnergyModel?>(
      EnergyModelNotifier.new,
    );

class EnergyModelNotifier extends AsyncNotifier<EnergyModel?> {
  @override
  Future<EnergyModel?> build() async {
    ref.watch(
      profileSetupProvider.select(
        (u) => (
          u.chronotype,
          u.wakeHour,
          u.bedHour,
          u.goal,
        ), // pick what matters
      ),
    );
    final repo = ref.read(energyRepositoryProvider);
    // Fetch authenticated user info
    final userProfile = await ref.watch(firestoreUserProvider.future);
    final user = ref.watch(firebaseUserProvider);
    if (user == null) return null;

    final chronotype = (userProfile['chronotype'] as String?) ?? 'Morning';

    // Load user-specific model or fallback
    return await repo.fetchUserEnergyModel(user.uid) ??
        await repo.fetchDefaultEnergyModel(chronotype, user.uid);
  }

  /// Explicit refresh of the EnergyModel
  Future<void> refreshModel() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Persist updated energy measurement back to Firestore
  Future<void> updateModel({
    required int hour,
    required double actualEnergy,
  }) async {
    final model = state.value;
    final user = ref.read(firebaseUserProvider);
    if (model == null || user == null) {
      throw StateError('No model loaded to update');
    }

    // Update in memory
    await model.update(hour, actualEnergy, user.uid);

    // Save whole model
    final repo = ref.read(energyRepositoryProvider);
    await repo.saveEnergyModel(user.uid, model);

    // Emit updated model
    state = AsyncData(model);
  }
}
