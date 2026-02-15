import 'dart:math';
import 'package:Watt/features/energy/models/sleep_quality.dart';
import 'package:Watt/utils/utils.dart';

import 'event.dart';

class EnergyModel {
  int defaultBedHour; // Added bedHour to match the original model
  int defaultWakeHour;
  int hoursSlept;
  num circadianPeakHour;
  double sPrev;
  double? sPrevNext;
  String? sPrevNextDay; // date (local) this sPrevNext applies to
  double sPrevDefault;
  double wS;
  double wC;
  num tau0;
  double tauSleep;

  double lrW;
  double lrCircadianPeak;
  double lrTau0;
  double lrTauSleep;

  EnergyModel({
    required this.defaultBedHour,
    required this.defaultWakeHour,
    required this.hoursSlept,
    required this.circadianPeakHour,
    required this.sPrev,
    this.sPrevNext,
    this.sPrevNextDay,
    required this.sPrevDefault,
    required this.wS,
    required this.wC,
    required this.tau0,
    required this.tauSleep,
    required this.lrW,
    required this.lrCircadianPeak,
    required this.lrTau0,
    required this.lrTauSleep,
  });

  factory EnergyModel.fromFirestore(
    Map<String, dynamic> userData,
    Map<String, dynamic> energyModelData,
  ) {
    final defaultWakeHour = intWithFallback(userData, 'wakeHour', 7);
    final defaultBedHour = intWithFallback(userData, 'bedHour', 23);
    final sPrevDefault = doubleWithFallback(
      energyModelData,
      'sPrevDefault',
      0.5,
    );

    return EnergyModel(
      defaultWakeHour: defaultWakeHour,
      defaultBedHour: defaultBedHour,
      hoursSlept: hourDifference(defaultBedHour, defaultWakeHour),
      circadianPeakHour: intWithFallback(
        energyModelData,
        'circadianPeakHour',
        9,
      ),

      sPrev: doubleWithFallback(energyModelData, 'sPrev', sPrevDefault),
      sPrevNext: doubleWithFallback(energyModelData, 'sPrevNext', sPrevDefault),
      sPrevNextDay: energyModelData['sPrevNextDay'] as String?,
      sPrevDefault: sPrevDefault,

      wS: doubleWithFallback(energyModelData, 'wS', 0.5),
      wC: doubleWithFallback(energyModelData, 'wC', 0.5),

      // these were num/double in your model — keep numeric
      tau0: doubleWithFallback(energyModelData, 'tau0', 16.0),
      tauSleep: doubleWithFallback(energyModelData, 'tauSleep', 4.5),
      lrW: doubleWithFallback(energyModelData, 'lrW', 0.01),
      lrCircadianPeak: doubleWithFallback(
        energyModelData,
        'lrCircadianPeak',
        0.01,
      ),
      lrTau0: doubleWithFallback(energyModelData, 'lrTau0', 0.001),
      lrTauSleep: doubleWithFallback(energyModelData, 'lrTauSleep', 0.001),
    );
  }

  // Convert EnergyModel to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'defaultWakeHour': defaultWakeHour,
      'defaultBedHour': defaultBedHour,
      'hoursSlept': hoursSlept,
      'circadianPeakHour': circadianPeakHour,
      'sPrev': sPrev,
      'sPrevNext': sPrevNext,
      'sPrevDefault': sPrevDefault,
      'wS': wS,
      'wC': wC,
      'tau0': tau0,
      'tauSleep': tauSleep,
      'lrW': lrW,
      'lrCircadianPeak': lrCircadianPeak,
      'lrTau0': lrTau0,
      'lrTauSleep': lrTauSleep,
    };
  }

  double _computeS0(SleepQualityRecord sleepQuality) {
    double adjustedHoursSlept = hoursSlept.toDouble();
    switch (sleepQuality.quality) {
      case SleepQuality.great:
        adjustedHoursSlept *= 1.2;
        break;
      case SleepQuality.good:
        adjustedHoursSlept *= 1.1;
        break;
      case SleepQuality.okay:
        break;
      case SleepQuality.poor:
        adjustedHoursSlept *= 0.9;
        break;
      case SleepQuality.veryPoor:
        adjustedHoursSlept *= 0.8;
        break;
    }
    return sPrev * exp((0 - adjustedHoursSlept) / tauSleep);
  }

  double _computeS(int hour, SleepQualityRecord sleepQuality) {
    final int tAwake = hourDifference(defaultWakeHour, hour);
    return 1 - (1 - _computeS0(sleepQuality)) * exp(-tAwake / tau0);
  }

  // double _computeC(int hour) {
  //   // Primary wave (24h period)
  //   double c1 = sin(2 * pi * (hour - circadianPeakHour) / 24 + pi / 2);

  //   // Secondary wave (12h period) - The "Post-Lunch Dip"
  //   // Amplitude 0.5 is heuristic; Phase shift aligns dip to ~6-7 hours after peak
  //   double c2 = 0.5 * sin(4 * pi * (hour - circadianPeakHour) / 24 + pi);

  //   // Normalize to roughly [-1, 1]
  //   return (c1 + c2) / 1.5;
  // }

  double _computeC(int hour) {
    // +pi/2 so that C is near-max at the peak hour
    return sin(2 * pi * (hour - circadianPeakHour) / 24 + pi / 2);
  }

  double predict(
    int hour,
    bool firstHour,
    bool lastHour,
    List<Event> events,
    SleepQualityRecord sleepQuality,
  ) {
    if (firstHour == true) {
      // sPrev update
      if (sPrevNextDay != null &&
          sPrevNextDay ==
              customDateString(dateWokeUp(defaultWakeHour, defaultBedHour))) {
        sPrev = sPrevNext ?? sPrev;
      }
    }

    final double S = _computeS(hour, sleepQuality);
    final double C = _computeC(hour);

    if (lastHour) {
      sPrevNext = S;
      sPrevNextDay = customDateString(
        dateWokeUp(defaultWakeHour, defaultBedHour).add(Duration(days: 1)),
      );
    }

    final double base = wS * (1 - S) + wC * ((C + 1) / 2);
    double energy = base * 100.0;

    if (events.isNotEmpty) {
      final double delta = events
          .map((e) => e.applyEffect(hour))
          .fold<double>(0.0, (a, b) => a + b);
      energy += delta;
    }
    return energy.clamp(0.0, 100.0).toDouble();
  }

  void updateWeights(
    int hour,
    double actualEnergy,
    String userId,
    List<Event> events,
    SleepQualityRecord sleepQuality,
  ) {
    final double S = _computeS(hour, sleepQuality);
    final double C = _computeC(hour);
    final double ePred = predict(hour, false, false, events, sleepQuality);

    // Map [0,100] -> [-1,1] for symmetric error surface
    final double rawPred = (ePred / 100.0) * 2.0 - 1.0;
    final double rawActual = (actualEnergy / 100.0) * 2.0 - 1.0;
    final double error = rawPred - rawActual;

    // --- Update weights (wS, wC) ---
    final double gradWS = error * (1.0 - S);
    final double gradWC = error * ((C + 1.0) / 2.0);
    wS -= lrW * gradWS;
    wC -= lrW * gradWC;

    // Clamp to [0,1] independently - NO normalization
    // Normalization inverts gradient direction when component magnitudes differ
    wS = wS.clamp(0.0, 1.0).toDouble();
    wC = wC.clamp(0.0, 1.0).toDouble();

    // --- Update circadian peak (phase) ---
    // Derivative matches the +pi/2 phase used in _computeC
    final double dCdp =
        -(2 * pi / 24.0) *
        cos(2 * pi * ((hour - circadianPeakHour) % 24) / 24.0 + pi / 2);
    final double gradPhi = error * wC * 0.5 * dCdp;

    double newPeak = circadianPeakHour - lrCircadianPeak * gradPhi;
    // Wrap safely into [0,24)
    circadianPeakHour = (((newPeak % 24.0) + 24.0) % 24.0).toDouble();
  }
}
