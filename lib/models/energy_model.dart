import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/event.dart';

class EnergyModel {
  int wakeTime;
  int hoursSlept;
  num circadianPeak;
  double SPrev;
  double wS;
  double wC;
  num tau0;
  double tauSleep;

  double lrW;
  double lrCircadianPeak;
  double lrTau0;
  double lrTauSleep;

  EnergyModel({
    required this.wakeTime,
    required this.hoursSlept,
    required this.circadianPeak,
    required this.SPrev,
    required this.wS,
    required this.wC,
    required this.tau0,
    required this.tauSleep,
    required this.lrW,
    required this.lrCircadianPeak,
    required this.lrTau0,
    required this.lrTauSleep,
  });

  // Factory constructor to create EnergyModel from Firestore data
  factory EnergyModel.fromFirestore(Map<String, dynamic> data) {
    return EnergyModel(
      wakeTime: data['wakeTime'],
      hoursSlept: data['hoursSlept'],
      circadianPeak: data['circadianPeak'],
      SPrev: data['SPrev'],
      wS: data['wS'],
      wC: data['wC'],
      tau0: data['tau0'],
      tauSleep: data['tauSleep'],
      lrW: data['lrW'],
      lrCircadianPeak: data['lrCircadianPeak'],
      lrTau0: data['lrTau0'],
      lrTauSleep: data['lrTauSleep'],
    );
  }

  // Firestore Integration: Fetch EnergyModel from Firestore
  static Future<EnergyModel?> fetchFromFirestore(String userId) async {
    final energyModelDoc = await FirebaseFirestore.instance
        .collection('User')
        .doc(userId)
        .collection('EnergyModel')
        .doc('default') // Assuming a single document named 'default'
        .get();

    if (energyModelDoc.exists) {
      return EnergyModel.fromFirestore(energyModelDoc.data()!);
    }
    return null; // Return null if no energy model exists
  }

  // Firestore Integration: Save EnergyModel to Firestore
  Future<void> saveToFirestore(String userId) async {
    await FirebaseFirestore.instance
        .collection('User')
        .doc(userId)
        .collection('EnergyModel')
        .doc('default') // Assuming a single document named 'default'
        .set(toFirestore());
  }

  // Convert EnergyModel to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'wakeTime': wakeTime,
      'hoursSlept': hoursSlept,
      'circadian_peak': circadianPeak,
      'SPrev': SPrev,
      'w_S': wS,
      'w_C': wC,
      'tau_0': tau0,
      'tau_sleep': tauSleep,
      'lrW': lrW,
      'lrCircadianPeak': lrCircadianPeak,
      'lrTau0': lrTau0,
      'lrTauSleep': lrTauSleep,
    };
  }

  double _computeS0() => SPrev * exp(-hoursSlept / tauSleep);

  double _computeS(int hour) {
    int tAwake = max(hour - wakeTime, 0);
    return 1 - (1 - _computeS0()) * exp(-tAwake / tau0);
  }

  double _computeC(int hour) =>
      sin(2 * pi * (hour - circadianPeak) / 24 + pi / 2);

  double predict(int hour, List<Event> events) {
    double S = _computeS(hour);
    double C = _computeC(hour);
    double base = wS * (1 - S) + wC * ((C + 1) / 2);
    double energy = base * 100 +
        (events.isNotEmpty
            ? events.map((e) => e.applyEffect(hour)).reduce((a, b) => a + b)
            : 0);
    return energy;
  }

  Future<void> update(int hour, double actualEnergy, String userId) async {
    double S = _computeS(hour);
    double C = _computeC(hour);
    double EPred = predict(hour, []);

    double rawPred = (EPred / 100) * 2 - 1;
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

    int tAwake = max(hour - wakeTime, 0);
    double dEtau0 = wS * (1 - S) * (tAwake / (tau0 * tau0));
    tau0 = (tau0 - lrTau0 * error * dEtau0).clamp(12.0, 20.0);

    double S0 = _computeS0();
    double expAwake = exp(-tAwake / tau0);
    double dEtauSleep =
        -wS * expAwake * S0 * (hoursSlept / (tauSleep * tauSleep));
    tauSleep = (tauSleep - lrTauSleep * error * dEtauSleep).clamp(3.0, 6.0);

    // Save updated values to Firestore
    await saveToFirestore(userId);
  }
}
