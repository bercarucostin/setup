// lib/features/energy/energy_providers.dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/energy/models/energy_feedback.dart';
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

bool _isBetween(int hour, int start, int end) {
  if (start <= end) {
    return hour >= start && hour < end;
  } else {
    return hour >= start || hour < end;
  }
}

/// Derived provider computing predicted energy points from the loaded model
final predictedEnergyProvider = FutureProvider<List<EnergyPoint>>((ref) async {
  final user = await ref.watch(signedInUserProvider.future);
  // final userData = ref.watch(userProfileDocProvider);
  final model = await ref.watch(energyModelProvider.future);

  if (model == null) {
    return const <EnergyPoint>[];
  }

  final events = await ref
      .watch(eventListProvider.future)
      .catchError((_) => const <Event>[]);
  final pts = <EnergyPoint>[];
  int currentHour = DateTime.now().hour;
  int hour = model.wakeHour;
  int maxHour = model.bedHour;
  if (_isBetween(currentHour, hour, maxHour) == false) {
    // if outside normal sleep hours
    int afterBedHour = (currentHour - model.bedHour + 24) % 24;
    int untilWakeHour = (model.wakeHour - currentHour + 24) % 24;
    if (afterBedHour <= untilWakeHour) {
      // if closer to bedtime, start from wakeTime to now
      hour = model.wakeHour;
      maxHour = currentHour;
    } else {
      // else start from now to bedtime
      hour = currentHour;
      maxHour = model.bedHour;
    }
  }

  while (hour != maxHour) {
    bool firstHour = false;
    if (hour == currentHour) {
      firstHour = true;
    }
    pts.add(EnergyPoint(hour, model.predict(hour, firstHour, false, events)));
    //print('Predicted energy at $hour: ${model.predict(hour, events)}');
    hour = (hour + 1) % 24;
  }

  pts.add(EnergyPoint(hour, model.predict(maxHour, false, true, events)));

  // Fire-and-forget save of updated model (no await)
  Future.microtask(() {
    ref.read(energyRepositoryProvider).saveEnergyModel(user.uid, model);
  });
  return pts;
});

// Map<int hour, EnergyFeedbackRecord> for TODAY
final todayFeedbackMapProvider = FutureProvider<Map<int, EnergyFeedbackRecord>>(
  (ref) async {
    // get user
    final user = await ref.watch(signedInUserProvider.future);
    if (user == null) {
      return <int, EnergyFeedbackRecord>{};
    }

    final repo = ref.read(energyRepositoryProvider);
    return repo.fetchUserEnergyFeedbackForToday(user.uid);
  },
);
