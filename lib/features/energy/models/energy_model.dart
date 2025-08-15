import 'dart:math';
import 'event.dart';

class EnergyModel {
  int bedHour; // Added bedHour to match the original model
  int wakeHour;
  int? hoursSlept;
  int? hoursSleptEpochDay; // which epoch-day (local) this hoursSlept applies to
  num circadianPeak;
  double sPrev;
  double sPrevNext;
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
    required this.bedHour,
    required this.wakeHour,
    this.hoursSlept,
    this.hoursSleptEpochDay,
    required this.circadianPeak,
    required this.sPrev,
    required this.sPrevNext,
    required this.sPrevNextEpochDay,
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

  // Factory constructor to create EnergyModel from merged Firestore data
  factory EnergyModel.fromFirestore(
    Map<String, dynamic> userData,
    Map<String, dynamic> energyModelData,
  ) {
    return EnergyModel(
      wakeHour: userData['wakeHour'],
      bedHour: userData['bedHour'],
      hoursSlept: energyModelData['hoursSlept'],
      hoursSleptEpochDay: energyModelData['hoursSleptEpochDay'],
      circadianPeak: energyModelData['circadianPeak'],
      sPrev: energyModelData['sPrev'] ?? energyModelData['sPrevDefault'],
      sPrevNext:
          energyModelData['sPrevNext'] ?? energyModelData['sPrevDefault'],
      sPrevNextEpochDay: energyModelData['sPrevNextEpochDay'],
      sPrevDefault: energyModelData['sPrevDefault'],
      wS: energyModelData['wS'],
      wC: energyModelData['wC'],
      tau0: energyModelData['tau0'],
      tauSleep: energyModelData['tauSleep'],
      lrW: energyModelData['lrW'],
      lrCircadianPeak: energyModelData['lrCircadianPeak'],
      lrTau0: energyModelData['lrTau0'],
      lrTauSleep: energyModelData['lrTauSleep'],
    );
  }

  // Convert EnergyModel to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'hoursSlept': hoursSlept,
      'hoursSleptEpochDay': hoursSleptEpochDay,
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

  int _hoursSlept() {
    if (hoursSlept != null &&
        hoursSleptEpochDay != null &&
        hoursSleptEpochDay == _epochDay(DateTime.now())) {
      return hoursSlept!;
    }
    // Calculate hours slept based on wakeHour and bedHour
    return (wakeHour - bedHour) % 24;
  }

  double _computeS0() {
    if (sPrevNextEpochDay != null &&
        sPrevNextEpochDay == _epochDay(DateTime.now())) {
      sPrev = sPrevNext;
    }
    return sPrev * exp(-(_hoursSlept()) / tauSleep);
  }

  double _computeS(int hour) {
    int tAwake = max((hour - wakeHour) % 24, 0);
    print(_computeS0());
    return 1 - (1 - _computeS0()) * exp(-tAwake / tau0);
  }

  double _computeC(int hour) {
    // +pi/2 so that C is near-max at the peak hour
    return sin(2 * pi * ((hour - circadianPeak) % 24) / 24 + pi / 2);
  }

  void updateHoursSlept(int hoursSlept) {
    this.hoursSlept = hoursSlept;
    this.hoursSleptEpochDay = _epochDay(DateTime.now());
  }

  double predict(int hour, List<Event> events) {
    final double S = _computeS(hour);
    final double C = _computeC(hour);

    if (hour == bedHour) {
      sPrevNext = S;
      sPrevNextEpochDay = _epochDay(
        DateTime.now().add(const Duration(days: 1)),
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
    print('Energy prediction for hour $hour: $energy');
    // Keep result interpretable for UI/learning
    return energy.clamp(0.0, 100.0).toDouble();
  }

  void updateWeights(int hour, double actualEnergy, String userId) {
    final double S = _computeS(hour);
    final double C = _computeC(hour);
    final double ePred = predict(hour, []);

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
    final int tAwake = max(hour - wakeHour, 0);
    final double dEtau0 = wS * (1.0 - S) * (tAwake / (tau0 * tau0));
    tau0 = (tau0 - lrTau0 * error * dEtau0).clamp(12.0, 20.0).toDouble();

    // --- Update tauSleep (sleep dissipation) ---
    final double S0 = _computeS0();
    final double expAwake = exp(-tAwake / tau0);
    final double dEtauSleep =
        -wS * expAwake * S0 * (_hoursSlept() / (tauSleep * tauSleep));
    tauSleep =
        (tauSleep - lrTauSleep * error * dEtauSleep).clamp(3.0, 6.0).toDouble();
  }
}
