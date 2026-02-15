import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:Watt/features/auth/providers/providers.dart'
    show authStateProvider, userProfileStreamProvider;
import 'package:Watt/features/energy/models/sleep_quality.dart';
import 'package:Watt/features/energy/repositories/energy_repository.dart';

import 'package:Watt/features/firestore/providers/providers.dart'
    show firestoreRepositoryProvider;

import 'package:Watt/features/energy/models/energy_feedback.dart';
import 'package:Watt/features/energy/models/energy_model.dart';
import 'package:Watt/features/energy/models/energy_point.dart';
import 'package:Watt/features/energy/models/event.dart';

/// Repository wiring
final energyRepositoryProvider = Provider<EnergyRepository>((ref) {
  final firestore = ref.read(firestoreRepositoryProvider);
  return EnergyRepository(firestore);
});

class EnergyInsightsState {
  final EnergyModel? model;
  final List<EnergyPoint> points;
  final List<Event> todayEvents;
  final Map<int, EnergyFeedbackRecord> todayFeedback;
  final SleepQualityRecord todaySleepQuality;

  const EnergyInsightsState({
    required this.model,
    required this.points,
    required this.todayEvents,
    required this.todayFeedback,
    required this.todaySleepQuality,
  });

  factory EnergyInsightsState.empty() => EnergyInsightsState(
    model: null,
    points: const <EnergyPoint>[],
    todayEvents: const <Event>[],
    todayFeedback: const <int, EnergyFeedbackRecord>{},
    todaySleepQuality: SleepQualityRecord(
      epochDay: '',
      quality: SleepQuality.okay,
    ),
  );

  EnergyInsightsState copyWith({
    EnergyModel? model,
    List<EnergyPoint>? points,
    List<Event>? todayEvents,
    Map<int, EnergyFeedbackRecord>? todayFeedback,
    SleepQualityRecord? todaySleepQuality,
  }) {
    return EnergyInsightsState(
      model: model ?? this.model,
      points: points ?? this.points,
      todayEvents: todayEvents ?? this.todayEvents,
      todayFeedback: todayFeedback ?? this.todayFeedback,
      todaySleepQuality: todaySleepQuality ?? this.todaySleepQuality,
    );
  }
}

final energyInsightsProvider =
    AsyncNotifierProvider<EnergyInsightsController, EnergyInsightsState>(
      EnergyInsightsController.new,
    );

class EnergyInsightsController extends AsyncNotifier<EnergyInsightsState> {
  @override
  Future<EnergyInsightsState> build() async {
    // 1) Auth
    final authAsync = ref.watch(authStateProvider);
    if (authAsync.isLoading) return EnergyInsightsState.empty();
    final user = authAsync.value;
    if (user == null) return EnergyInsightsState.empty();

    // 2) Profile (first emission)
    final profile = await ref.watch(userProfileStreamProvider(user.uid).future);
    if (profile == null) return EnergyInsightsState.empty();

    final chronotype = profile['chronotype'];
    final wakeHour = profile['wakeHour'];
    final bedHour = profile['bedHour'];
    if (chronotype == null || wakeHour == null || bedHour == null) {
      return EnergyInsightsState.empty();
    }

    final repo = ref.read(energyRepositoryProvider);

    // 3) Load model (user model OR default)
    final model = await repo.loadOrDefaultModel(
      userId: user.uid,
      profile: profile,
    );

    // 4) Load today events + feedback
    final results = await Future.wait([
      repo.fetchUserEventsForToday(user.uid),
      repo.fetchUserEnergyFeedbackForToday(user.uid),
      repo.fetchUserSleepQualityForToday(user.uid),
    ]);

    final events = results[0] as List<Event>;
    final feedback = results[1] as Map<int, EnergyFeedbackRecord>;
    final sleepQuality = results[2] as SleepQualityRecord;
    print("bossult");
    print(sleepQuality.quality);

    // 5) Compute curve wake->bed and persist model (safe)
    final points = repo.buildDailyEnergyCurve(
      model: model,
      events: events,
      sleepQuality: sleepQuality,
    );
    await repo.saveEnergyModel(user.uid, model);

    return EnergyInsightsState(
      model: model,
      points: points,
      todayEvents: events,
      todayFeedback: feedback,
      todaySleepQuality: sleepQuality,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// New submit: takes enum feedback + predictedEnergy
  Future<void> submitFeedback({
    required int hour,
    required EnergyFeedback feedback,
    required double predictedEnergy,
  }) async {
    final current = state.asData?.value; // ✅ fixes valueOrNull issue
    final user = ref.read(authStateProvider).value;
    if (current == null || user == null) return;

    final model = current.model;
    if (model == null) return;

    final repo = ref.read(energyRepositoryProvider);

    // 1) Save feedback doc
    final record = EnergyFeedbackRecord(
      hour: hour,
      feedback: feedback,
      wS: model.wS,
      wC: model.wC,
      circadianPeakHour: model.circadianPeakHour,
      hoursSlept: model.hoursSlept,
      sPrev: model.sPrev,
      wakeHour: model.defaultWakeHour,
      bedHour: model.defaultBedHour,
      predictedEnergy: predictedEnergy,
    );
    await repo.saveUserEnergyFeedback(userId: user.uid, record: record);

    // 2) Train model (convert enum -> adjusted "actualEnergy")
    double adjusted = predictedEnergy;
    switch (feedback) {
      case EnergyFeedback.muchHigher:
        adjusted *= 1.2;
        break;
      case EnergyFeedback.higher:
        adjusted *= 1.1;
        break;
      case EnergyFeedback.match:
        break;
      case EnergyFeedback.lower:
        adjusted *= 0.9;
        break;
      case EnergyFeedback.muchLower:
        adjusted *= 0.8;
        break;
    }
    adjusted = adjusted.clamp(0.0, 100.0);

    // Filter events that affect this specific hour
    final eventsAtHour = current.todayEvents
        .where((e) => e.applyEffect(hour) != 0.0)
        .toList();

    model.updateWeights(
      hour,
      adjusted,
      user.uid,
      eventsAtHour,
      current.todaySleepQuality,
    );
    await repo.saveEnergyModel(user.uid, model);

    // 3) Reload feedback + recompute curve
    final feedbackMap = await repo.fetchUserEnergyFeedbackForToday(user.uid);
    final points = repo.buildDailyEnergyCurve(
      model: model,
      events: current.todayEvents,
      sleepQuality: current.todaySleepQuality,
    );

    state = AsyncData(
      current.copyWith(
        model: model,
        points: points,
        todayFeedback: feedbackMap,
      ),
    );
  }
}
