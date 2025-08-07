// lib/features/energy/energy_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/energy/repository/repository.dart';
import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/controllers/energy_view_model.dart';

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
  if (modelAsync.isLoading || modelAsync.hasError || modelAsync.value == null) {
    return const [];
  }
  final model = modelAsync.value!;
  final pts = <EnergyPoint>[];
  var hour = model.wakeTime;
  while (hour != model.bedTime) {
    pts.add(EnergyPoint(hour!, model.predict(hour, [])));
    hour = (hour + 1) % 24;
  }
  return pts;
});
