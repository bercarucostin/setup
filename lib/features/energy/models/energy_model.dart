import 'dart:math';
import 'event.dart';

class EnergyModel {
  int? bedTime; // Added bedTime to match the original model
  int? wakeTime;
  int hoursSlept;
  num circadianPeak;
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
    required this.bedTime,
    required this.wakeTime,
    required this.hoursSlept,
    required this.circadianPeak,
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
      wakeTime: userData['wakeTime'],
      bedTime: userData['bedTime'],
      hoursSlept: energyModelData['hoursSlept'],
      circadianPeak: energyModelData['circadianPeak'],
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
  //   final userData = <String, dynamic>{'wakeTime': null, 'bedTime': null};

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

  // Future<void> _updateWakeTime(String userId) async {
  //   // Fetch today's date range
  //   final today = DateTime.now();
  //   final startOfDay = DateTime(today.year, today.month, today.day);
  //   final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

  //   // Fetch the latest 'wake_time' feedback
  //   QuerySnapshot wakeTimeSnapshot =
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

  //   if (wakeTimeSnapshot.docs.isNotEmpty) {
  //     UserFeedback latestWakeTimeFeedback = UserFeedback.fromFirestore(
  //       wakeTimeSnapshot.docs.first.data() as Map<String, dynamic>,
  //     );
  //     wakeTime =
  //         latestWakeTimeFeedback.value
  //             .toInt(); // Update wakeTime if feedback exists
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
  //             .toInt(); // Update wakeTime if feedback exists
  //     hoursSlept = (4 + (sleepQuality - 1) * (5 / 9)).toInt();
  //   }
  // }

  double _computeS0() => sPrev * exp(-hoursSlept / tauSleep);

  double _computeS(int hour) {
    int tAwake = max(hour - wakeTime!, 0);
    return 1 - (1 - _computeS0()) * exp(-tAwake / tau0);
  }

  double _computeC(int hour) =>
      sin(2 * pi * (hour - circadianPeak) / 24 + pi / 2);

  double predict(int hour, List<Event> events) {
    double S = _computeS(hour);
    double C = _computeC(hour);
    double base = wS * (1 - S) + wC * ((C + 1) / 2);
    double energy =
        base * 100 +
        (events.isNotEmpty
            ? events.map((e) => e.applyEffect(hour)).reduce((a, b) => a + b)
            : 0);
    return energy;
  }

  Future<void> update(int hour, double actualEnergy, String userId) async {
    // await _updateWakeTime(userId);
    // await _updateHoursSlept(userId);
    double S = _computeS(hour);
    double C = _computeC(hour);
    double ePred = predict(hour, []);

    double rawPred = (ePred / 100) * 2 - 1;
    double rawActual = (actualEnergy / 100) * 2 - 1;
    double error = rawPred - rawActual;

    double gradWS = error * (1 - S);
    double gradWC = error * ((C + 1) / 2);
    wS -= lrW * gradWS;
    wC -= lrW * gradWC;
    double total = wS + wC;
    if (total > 0) {
      wS /= total;
      wC /= total;
    } else {
      wS = 0.5;
      wC = 0.5;
    }

    double dCdp = -(2 * pi / 24) * cos(2 * pi * (hour - circadianPeak) / 24);
    double gradPhi = error * wC * 0.5 * dCdp;
    circadianPeak = (circadianPeak - lrCircadianPeak * gradPhi) % 24;

    int tAwake = max(hour - wakeTime!, 0);
    double dEtau0 = wS * (1 - S) * (tAwake / (tau0 * tau0));
    tau0 = (tau0 - lrTau0 * error * dEtau0).clamp(12.0, 20.0);

    double S0 = _computeS0();
    double expAwake = exp(-tAwake / tau0);
    double dEtauSleep =
        -wS * expAwake * S0 * (hoursSlept / (tauSleep * tauSleep));
    tauSleep = (tauSleep - lrTauSleep * error * dEtauSleep).clamp(3.0, 6.0);

    // Save updated values to Firestore
    // await saveToFirestore(userId);
  }
}
