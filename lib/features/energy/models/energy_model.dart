import 'dart:math';
import 'event.dart';

class EnergyModel {
  int bedHour; // Added bedHour to match the original model
  int wakeHour;
  int hoursSlept;
  num circadianPeak;
  // double sPrevNext;
  double sPrev;
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
    required this.hoursSlept,
    required this.circadianPeak,
    // required this.sPrevNext,
    required this.sPrev,
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
      circadianPeak: energyModelData['circadianPeak'],
      // sPrevNext: energyModelData['sPrevNext'],
      sPrev: energyModelData['sPrev'],
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

  // // Firestore Integration: Fetch EnergyModel from Firestore
  // static Future<EnergyModel?> fetchFromFirestore(String userId) async {
  //   final userDocRef = FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(userId);
  //   final energyModelDocRef = userDocRef
  //       .collection('energyModel')
  //       .doc('default');

  //   final userDoc = await userDocRef.get();
  //   final energyModelDoc = await energyModelDocRef.get();

  //   if (userDoc.exists && energyModelDoc.exists) {
  //     final userData = userDoc.data()!;
  //     final energyModelData = energyModelDoc.data()!;

  //     return EnergyModel.fromFirestore(userData, energyModelData);
  //   }
  //   return null;
  // }

  // Firestore Integration: Fetch default EnergyModel for a chronotype
  // static Future<EnergyModel?> fetchDefaultEnergyModel(String chronotype) async {
  //   // Fetch default energy model for the given chronotype
  //   final defaultDoc =
  //       await FirebaseFirestore.instance
  //           .collection('energyModelDefaults')
  //           .doc(chronotype)
  //           .get();

  //   if (!defaultDoc.exists) {
  //     return null; // No defaults for this chronotype
  //   }

  //   final energyModelData = defaultDoc.data()!;

  //   // For defaults, there is no user data; we can provide dummy wake/bed times
  //   // Or decide that these fields will be null-safe in the model
  //   final userData = <String, dynamic>{'wakeHour': null, 'bedHour': null};

  //   return EnergyModel.fromFirestore(userData, energyModelData);
  // }

  // Firestore Integration: Save EnergyModel to Firestore
  // Future<void> saveToFirestore(String userId) async {
  //   await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(userId)
  //       .collection('energyModel')
  //       .doc('default') // Assuming a single document named 'default'
  //       .set(toFirestore());
  // }

  // Convert EnergyModel to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'hoursSlept': hoursSlept,
      'circadianPeak': circadianPeak,
      // 'sPrevNext': sPrevNext,
      'sPrev': sPrev,
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

  // Future<void> _updatewakeHour(String userId) async {
  //   // Fetch today's date range
  //   final today = DateTime.now();
  //   final startOfDay = DateTime(today.year, today.month, today.day);
  //   final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

  //   // Fetch the latest 'wake_time' feedback
  //   QuerySnapshot wakeHourSnapshot =
  //       await FirebaseFirestore.instance
  //           .collection('Feedback')
  //           .where('userId', isEqualTo: userId)
  //           .where(
  //             'timestamp',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
  //           )
  //           .where(
  //             'timestamp',
  //             isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
  //           )
  //           .where('type', isEqualTo: 'wake_time')
  //           .orderBy('timestamp', descending: true)
  //           .limit(1)
  //           .get();

  //   if (wakeHourSnapshot.docs.isNotEmpty) {
  //     UserFeedback latestwakeHourFeedback = UserFeedback.fromFirestore(
  //       wakeHourSnapshot.docs.first.data() as Map<String, dynamic>,
  //     );
  //     wakeHour =
  //         latestwakeHourFeedback.value
  //             .toInt(); // Update wakeHour if feedback exists
  //   }
  // }

  // Future<void> _updateHoursSlept(String userId) async {
  //   // Fetch today's date range
  //   final today = DateTime.now();
  //   final startOfDay = DateTime(today.year, today.month, today.day);
  //   final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

  //   // Fetch the latest 'sleep_quality' feedback
  //   QuerySnapshot sleepQualitySnapshot =
  //       await FirebaseFirestore.instance
  //           .collection('Feedback')
  //           .where('userId', isEqualTo: userId)
  //           .where(
  //             'timestamp',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
  //           )
  //           .where(
  //             'timestamp',
  //             isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
  //           )
  //           .where('type', isEqualTo: 'sleep_quality')
  //           .orderBy('timestamp', descending: true)
  //           .limit(1)
  //           .get();

  //   if (sleepQualitySnapshot.docs.isNotEmpty) {
  //     UserFeedback latestSleepQualityFeedback = UserFeedback.fromFirestore(
  //       sleepQualitySnapshot.docs.first.data() as Map<String, dynamic>,
  //     );
  //     int sleepQuality =
  //         latestSleepQualityFeedback.value
  //             .toInt(); // Update wakeHour if feedback exists
  //     hoursSlept = (4 + (sleepQuality - 1) * (5 / 9)).toInt();
  //   }
  // }

  double _computeS0() => sPrev * exp(-hoursSlept / tauSleep);

  double _computeS(int hour) {
    int tAwake = max(hour - wakeHour, 0);
    return 1 - (1 - _computeS0()) * exp(-tAwake / tau0);
  }

  double _computeC(int hour) {
    // +pi/2 so that C is near-max at the peak hour
    return sin(2 * pi * (hour - circadianPeak) / 24 + pi / 2);
  }

  double predict(int hour, List<Event> events) {
    final double S = _computeS(hour);
    final double C = _computeC(hour);

    final double base = wS * (1 - S) + wC * ((C + 1) / 2);
    double energy = base * 100.0;

    if (events.isNotEmpty) {
      final double delta = events
          .map((e) => e.applyEffect(hour))
          .fold<double>(0.0, (a, b) => a + b);
      energy += delta;
    }

    // Keep result interpretable for UI/learning
    return energy.clamp(0.0, 100.0).toDouble();
  }

  Future<void> update(int hour, double actualEnergy, String userId) async {
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
        -(2 * pi / 24.0) * cos(2 * pi * (hour - circadianPeak) / 24.0 + pi / 2);
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
        -wS * expAwake * S0 * (hoursSlept / (tauSleep * tauSleep));
    tauSleep =
        (tauSleep - lrTauSleep * error * dEtauSleep).clamp(3.0, 6.0).toDouble();
  }
}
