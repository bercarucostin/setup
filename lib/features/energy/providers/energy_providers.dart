import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peak_flow/features/auth/providers/providers.dart'
    show authStateProvider, userProfileStreamProvider;
import 'package:peak_flow/features/energy/repositories/energy_repository.dart';

import 'package:peak_flow/features/firestore/providers/providers.dart'
    show firestoreRepositoryProvider;

import 'package:peak_flow/features/energy/models/energy_feedback.dart';
import 'package:peak_flow/features/energy/models/energy_model.dart';
import 'package:peak_flow/features/energy/models/energy_point.dart';
import 'package:peak_flow/features/energy/models/event.dart';

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

  const EnergyInsightsState({
    required this.model,
    required this.points,
    required this.todayEvents,
    required this.todayFeedback,
  });

  factory EnergyInsightsState.empty() => const EnergyInsightsState(
    model: null,
    points: <EnergyPoint>[],
    todayEvents: <Event>[],
    todayFeedback: <int, EnergyFeedbackRecord>{},
  );

  EnergyInsightsState copyWith({
    EnergyModel? model,
    List<EnergyPoint>? points,
    List<Event>? todayEvents,
    Map<int, EnergyFeedbackRecord>? todayFeedback,
  }) {
    return EnergyInsightsState(
      model: model ?? this.model,
      points: points ?? this.points,
      todayEvents: todayEvents ?? this.todayEvents,
      todayFeedback: todayFeedback ?? this.todayFeedback,
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
      chronotype: chronotype as String,
    );

    // 4) Load today events + feedback
    final results = await Future.wait([
      repo.fetchUserEventsForToday(user.uid),
      repo.fetchUserEnergyFeedbackForToday(user.uid),
    ]);

    final events = results[0] as List<Event>;
    final feedback = results[1] as Map<int, EnergyFeedbackRecord>;

    // 5) Compute curve wake->bed and persist model (safe)
    final points = repo.buildDailyEnergyCurve(model: model, events: events);
    await repo.saveEnergyModel(user.uid, model);

    return EnergyInsightsState(
      model: model,
      points: points,
      todayEvents: events,
      todayFeedback: feedback,
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
      predictedEnergy: predictedEnergy,
    );
    await repo.saveUserEnergyFeedback(userId: user.uid, record: record);

    // 2) Train model (convert enum -> adjusted "actualEnergy")
    double adjusted = predictedEnergy;
    switch (feedback) {
      case EnergyFeedback.muchHigher:
        adjusted += 10;
        break;
      case EnergyFeedback.higher:
        adjusted += 5;
        break;
      case EnergyFeedback.match:
        break;
      case EnergyFeedback.lower:
        adjusted -= 5;
        break;
      case EnergyFeedback.muchLower:
        adjusted -= 10;
        break;
    }
    adjusted = adjusted.clamp(0.0, 100.0);

    model.updateWeights(hour, adjusted, user.uid);
    await repo.saveEnergyModel(user.uid, model);

    // 3) Reload feedback + recompute curve
    final feedbackMap = await repo.fetchUserEnergyFeedbackForToday(user.uid);
    final points = repo.buildDailyEnergyCurve(
      model: model,
      events: current.todayEvents,
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
