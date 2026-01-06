import 'dart:math';
import 'event.dart';

class EnergyModel {
  int defaultBedHour; // Added bedHour to match the original model
  int defaultWakeHour;
  int? wakeHour;
  int? bedHour;
  int? bedHourLastDay;
  int? bedHourLastDayEpochDay;
  int? hoursSlept;
  num circadianPeak;
  double sPrev;
  double? sPrevNext;
  int? sPrevNextEpochDay; // which epoch-day (local) this sPrevNext applies to
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
    this.wakeHour,
    this.bedHour,
    this.bedHourLastDay,
    this.bedHourLastDayEpochDay,
    this.hoursSlept,
    required this.circadianPeak,
    required this.sPrev,
    this.sPrevNext,
    this.sPrevNextEpochDay,
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

  static double _d(Map<String, dynamic> m, String k, double fallback) {
    final v = m[k];
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    throw StateError('Field "$k" must be a number, got ${v.runtimeType}');
  }

  static int _i(Map<String, dynamic> m, String k, int fallback) {
    final v = m[k];
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    throw StateError('Field "$k" must be a number, got ${v.runtimeType}');
  }

  factory EnergyModel.fromFirestore(
    Map<String, dynamic> userData,
    Map<String, dynamic> energyModelData,
  ) {
    final defaultWake = _i(userData, 'wakeHour', 7);
    final defaultBed = _i(userData, 'bedHour', 23);

    return EnergyModel(
      defaultWakeHour: defaultWake,
      defaultBedHour: defaultBed,

      wakeHour: _i(energyModelData, 'wakeHour', defaultWake),
      bedHour: _i(energyModelData, 'bedHour', defaultBed),

      bedHourLastDay: (energyModelData['bedHourLastDay'] as num?)?.toInt(),
      bedHourLastDayEpochDay:
          (energyModelData['bedHourLastDayEpochDay'] as num?)?.toInt(),
      hoursSlept: (energyModelData['hoursSlept'] as num?)?.toInt(),

      circadianPeak: _d(energyModelData, 'circadianPeak', 15.0),
      sPrev: _d(energyModelData, 'sPrev', 0.5),
      sPrevNext: (energyModelData['sPrevNext'] as num?)?.toDouble(),
      sPrevNextEpochDay: (energyModelData['sPrevNextEpochDay'] as num?)
          ?.toInt(),
      sPrevDefault: _d(energyModelData, 'sPrevDefault', 0.5),

      wS: _d(energyModelData, 'wS', 0.5),
      wC: _d(energyModelData, 'wC', 0.5),

      // these were num/double in your model — keep numeric
      tau0: _d(energyModelData, 'tau0', 16.0),
      tauSleep: _d(energyModelData, 'tauSleep', 4.5),

      lrW: _d(energyModelData, 'lrW', 0.01),
      lrCircadianPeak: _d(energyModelData, 'lrCircadianPeak', 0.01),
      lrTau0: _d(energyModelData, 'lrTau0', 0.001),
      lrTauSleep: _d(energyModelData, 'lrTauSleep', 0.001),
    );
  }

  // Convert EnergyModel to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'wakeHour': wakeHour,
      'bedHour': bedHour,
      'bedHourLastDay': bedHourLastDay,
      'bedHourLastDayEpochDay': bedHourLastDayEpochDay,
      'hoursSlept': hoursSlept,
      'circadianPeak': circadianPeak,
      'sPrev': sPrev,
      'sPrevNext': sPrevNext,
      'sPrevNextEpochDay': sPrevNextEpochDay,
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

  int _epochDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;

  double _computeS0() {
    return sPrev * exp((0 - hoursSlept!) / tauSleep);
  }

  double _computeS(int hour) {
    final int tAwake = (hour - (wakeHour ?? defaultWakeHour)) % 24;
    return 1 - (1 - _computeS0()) * exp(-tAwake / tau0);
  }

  double _computeC(int hour) {
    // +pi/2 so that C is near-max at the peak hour
    return sin(2 * pi * (hour - circadianPeak) / 24 + pi / 2);
  }

  // void updateHoursSlept(int hoursSlept) {
  //   this.hoursSlept = hoursSlept;
  //   this.hoursSleptEpochDay = _epochDay(DateTime.now());
  // }

  double predict(int hour, bool firstHour, bool lastHour, List<Event> events) {
    if (firstHour == true) {
      // sPrev update
      if (sPrevNextEpochDay != null &&
          sPrevNextEpochDay == _epochDay(DateTime.now())) {
        sPrev = sPrevNext!;
      } else {
        sPrev = sPrevDefault;
      }

      // hoursSlept update
      if (bedHourLastDayEpochDay != null &&
          bedHourLastDayEpochDay == _epochDay(DateTime.now())) {
        bedHour = bedHourLastDay!;
      } else {
        bedHour = defaultBedHour;
      }
      wakeHour = hour;
      hoursSlept = (hour - bedHour!) % 24;
    }

    final double S = _computeS(hour);
    final double C = _computeC(hour);

    if (lastHour) {
      sPrevNext = S;
      bedHourLastDay = hour;
      if ([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].contains(hour)) {
        sPrevNextEpochDay = _epochDay(DateTime.now());
        bedHourLastDayEpochDay = _epochDay(DateTime.now());
      } else {
        sPrevNextEpochDay = _epochDay(
          DateTime.now().add(const Duration(days: 1)),
        );
        bedHourLastDayEpochDay = _epochDay(
          DateTime.now().add(const Duration(days: 1)),
        );
      }
    }

    final double base = wS * (1 - S) + wC * ((C + 1) / 2);
    double energy = base * 100.0;

    if (events.isNotEmpty) {
      final double delta = events
          .map((e) => e.applyEffect(hour))
          .fold<double>(0.0, (a, b) => a + b);
      energy += delta;
    }
    // print('Energy prediction for hour $hour: $energy');
    // Keep result interpretable for UI/learning
    return energy.clamp(0.0, 100.0).toDouble();
  }

  void updateWeights(int hour, double actualEnergy, String userId) {
    final double S = _computeS(hour);
    final double C = _computeC(hour);
    final double ePred = predict(hour, false, false, []);

    // Map [0,100] -> [-1,1] for symmetric error surface
    final double rawPred = (ePred / 100.0) * 2.0 - 1.0;
    final double rawActual = (actualEnergy / 100.0) * 2.0 - 1.0;
    final double error = rawPred - rawActual;

    // --- Update weights (wS, wC) ---
    final double gradWS = error * (1.0 - S);
    final double gradWC = error * ((C + 1.0) / 2.0);
    wS -= lrW * gradWS;
    wC -= lrW * gradWC;

    // Clamp to [0,1] then renormalize to sum to 1
    wS = wS.clamp(0.0, 1.0).toDouble();
    wC = wC.clamp(0.0, 1.0).toDouble();
    double total = wS + wC;
    if (total == 0.0) {
      wS = 0.5;
      wC = 0.5;
      total = 1.0;
    } else {
      wS /= total;
      wC /= total;
    }

    // --- Update circadian peak (phase) ---
    // Derivative matches the +pi/2 phase used in _computeC
    final double dCdp =
        -(2 * pi / 24.0) *
        cos(2 * pi * ((hour - circadianPeak) % 24) / 24.0 + pi / 2);
    final double gradPhi = error * wC * 0.5 * dCdp;

    double newPeak = circadianPeak - lrCircadianPeak * gradPhi;
    // Wrap safely into [0,24)
    circadianPeak = (((newPeak % 24.0) + 24.0) % 24.0).toDouble();

    // --- Update tau0 (wake time constant) ---
    final int tAwake = max(hour - (wakeHour ?? defaultWakeHour), 0);
    final double dEtau0 = wS * (1.0 - S) * (tAwake / (tau0 * tau0));
    tau0 = (tau0 - lrTau0 * error * dEtau0).clamp(12.0, 20.0).toDouble();

    // --- Update tauSleep (sleep dissipation) ---
    final double S0 = _computeS0();
    final double expAwake = exp(-tAwake / tau0);
    final double dEtauSleep =
        -wS *
        expAwake *
        S0 *
        ((hoursSlept ?? (defaultWakeHour - defaultBedHour) % 24) /
            (tauSleep * tauSleep));
    tauSleep = (tauSleep - lrTauSleep * error * dEtauSleep)
        .clamp(3.0, 6.0)
        .toDouble();
  }
}
