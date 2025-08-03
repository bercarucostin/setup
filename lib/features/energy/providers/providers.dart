// Repository Providers
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/energy/controllers/energy_view_model.dart';
import 'package:setup/features/energy/repository/repository.dart';
import 'package:setup/features/firestore/providers/providers.dart';

final energyRepositoryProvider = Provider<EnergyRepository>((ref) {
  final firestoreRepo = ref.read(firestoreRepositoryProvider);
  return EnergyRepository(firestoreRepo);
});

final energyViewModelProvider = ChangeNotifierProvider<EnergyViewModel>((ref) {
  final repository = ref.read(energyRepositoryProvider);
  return EnergyViewModel(repository);
});
