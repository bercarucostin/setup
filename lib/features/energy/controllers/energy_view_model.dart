// lib/features/energy/energy_view_model.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/energy/models/energy_point.dart';
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
    final repo = ref.read(energyRepositoryProvider);
    // Fetch authenticated user info
    final userProfile = await ref.watch(firestoreUserProvider.future);
    final user = FirebaseAuth.instance.currentUser!;
    final chronotype = userProfile['chronotype'] as String;

    // Load user-specific model or fallback
    return await repo.fetchUserEnergyModel(user.uid) ??
        await repo.fetchDefaultEnergyModel(chronotype);
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
    final model = state.requireValue;
    if (model == null) {
      throw StateError('No model loaded to update');
    }
    final userId = FirebaseAuth.instance.currentUser!.uid;
    // Update the model in memory
    model.update(hour, actualEnergy, userId);
    // Save via repository
    final repo = ref.read(energyRepositoryProvider);
    await repo.saveEnergyModel(userId, model);
    // Emit updated model
    state = AsyncData(model);
  }
}

/// Derived provider computing predicted energy points from the loaded model
final predictedEnergyProvider = Provider<List<EnergyPoint>>((ref) {
  final modelAsync = ref.watch(energyModelProvider);
  if (modelAsync.isLoading || modelAsync.hasError || modelAsync.value == null) {
    return const [];
  }
  final model = modelAsync.value!;
  final pts = <EnergyPoint>[];
  var hour = model.wakeTime;
  while (hour != model.bedTime) {
    pts.add(EnergyPoint(hour, model.predict(hour, [])));
    hour = (hour + 1) % 24;
  }
  // Fire-and-forget save of updated model (no await)
  Future.microtask(() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    ref.read(energyRepositoryProvider).saveEnergyModel(userId, model);
  });
  return pts;
});
