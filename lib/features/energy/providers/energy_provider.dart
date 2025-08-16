// lib/features/energy/energy_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/energy/models/event.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/energy/repository/energy_repository.dart';
import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/controllers/energy_view_model.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/energy/providers/events_provider.dart';

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
  final eventsAsync = ref.watch(eventListProvider);
  final List<Event> events = eventsAsync.maybeWhen(
    data: (e) => e,
    orElse: () => const <Event>[],
  );
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
  int steps = 0;
  while (hour != model.bedHour && steps < 24) {
    pts.add(EnergyPoint(hour, model.predict(hour, events)));
    print('Predicted energy at $hour: ${model.predict(hour, events)}');
    hour = (hour + 1) % 24;
    steps++;
  }

  // Hit bedtime once to snapshot sPrevNext for tomorrow
  model.predict(model.bedHour, events);

  // Fire-and-forget save of updated model (no await)
  Future.microtask(() {
    ref.read(energyRepositoryProvider).saveEnergyModel(user.uid, model);
  });
  return pts;
});
