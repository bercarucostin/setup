// lib/features/energy/energy_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/energy/repository/repository.dart';
import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/controllers/energy_view_model.dart';
import 'package:setup/features/auth/providers/providers.dart';

/// Wraps FirestoreRepository into EnergyRepository
final energyRepositoryProvider = Provider<EnergyRepository>((ref) {
  final firestore = ref.read(firestoreRepositoryProvider);
  return EnergyRepository(firestore);
});

/// Exposes the EnergyModelNotifier
final energyModelProvider =
    AsyncNotifierProvider<EnergyModelNotifier, EnergyModel?>(
      EnergyModelNotifier.new,
    );

/// Derived provider computing predicted energy points from the loaded model
final predictedEnergyProvider = Provider<List<EnergyPoint>>((ref) {
  final modelAsync = ref.watch(energyModelProvider);
  final user = ref.watch(firebaseUserProvider);
  if (user == null ||
      modelAsync.isLoading ||
      modelAsync.hasError ||
      modelAsync.value == null) {
    return const [];
  }
  final model = modelAsync.value!;
  final pts = <EnergyPoint>[];

  var hour = model.wakeHour;
  while ((hour <= model.bedHour) && !((model.bedHour == 23) && (hour == 0))) {
    final energy = model.predict(hour, const []);
    pts.add(EnergyPoint(hour, energy));
    hour = (hour + 1) % 24;
  }
  // Fire-and-forget save of updated model (no await)
  Future.microtask(() {
    ref.read(energyRepositoryProvider).saveEnergyModel(user.uid, model);
  });

  return pts;
});
