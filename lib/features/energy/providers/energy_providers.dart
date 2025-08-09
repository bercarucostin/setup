// lib/features/energy/energy_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/energy/repository/repository.dart';
import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/controllers/energy_view_model.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/auth/models/auth_state.dart';

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

final onLoginRefreshEnergyModelProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    final wasLoggedOut = prev is! Authenticated;
    final isLoggedIn = next is Authenticated;
    if (wasLoggedOut && isLoggedIn) {
      // Force a reload of the Firestore-backed model
      ref.read(energyModelProvider.notifier).refreshModel();
    }
  });
});

/// Derived provider computing predicted energy points from the loaded model
final predictedEnergyProvider = Provider<List<EnergyPoint>>((ref) {
  ref.watch(onLoginRefreshEnergyModelProvider);

  final modelAsync = ref.watch(energyModelProvider);
  if (modelAsync.isLoading || modelAsync.hasError || modelAsync.value == null) {
    return const [];
  }
  final model = modelAsync.value!;
  final pts = <EnergyPoint>[];
  var hour = model.wakeHour;
  while (hour != model.bedHour) {
    pts.add(EnergyPoint(hour, model.predict(hour, [])));
    hour = (hour + 1) % 24;
  }
  return pts;
});
