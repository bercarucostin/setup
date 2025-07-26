import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firestore_repository.dart';
import '../../viewmodels/energy_view_model.dart';

// Repository Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  return FirestoreRepository();
});

final energyViewModelProvider = ChangeNotifierProvider<EnergyViewModel>((ref) {
  return EnergyViewModel();
});
