import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/energy_model.dart';

class EnergyViewModel extends ChangeNotifier {
  EnergyModel? _model; // Make the model nullable to handle initialization
  final List<EnergyPoint> predictedEnergy = [];

  // Method to fetch EnergyModel for a specific userId
  Future<void> fetchEnergyModel(String userId) async {
    final model = await EnergyModel.fetchFromFirestore(userId);
    if (model != null) {
      _model = model;
      notifyListeners(); // Notify listeners after fetching the model
    } else {
      throw Exception('EnergyModel not found for userId: $userId');
    }
  }

  void computeEnergyPrediction() {
    if (_model == null) {
      throw Exception(
        'EnergyModel is not initialized. Call fetchEnergyModel first.',
      );
    }

    predictedEnergy.clear();
    final wakeTime = _model!.wakeTime; // Get wakeTime from the model
    final bedTime = _model!.bedTime;
    var hour = wakeTime;
    // Loop until hour == bedTime, wrapping around 24h if needed
    while (hour != bedTime) {
      final energy = _model!.predict(hour, []);
      predictedEnergy.add(EnergyPoint(hour, energy));
      hour = (hour + 1) % 24;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> updateModel(int hour, double actualEnergy, String userId) async {
    if (_model == null) {
      throw Exception(
        'EnergyModel is not initialized. Call fetchEnergyModel first.',
      );
    }

    await _model!.update(
      hour,
      actualEnergy,
      userId,
    ); // Update and save to Firestore
    notifyListeners(); // Notify listeners after updating the model
  }

  List<int> getDisplayedHours({int gap = 3}) {
    if (_model == null) return [];
    final wakeTime = _model!.wakeTime;
    final bedTime = _model!.bedTime;
    List<int> hours = [];
    int hour = wakeTime;
    while (hour != bedTime) {
      hours.add(hour);
      hour = (hour + gap) % 24;
      // Stop if we've looped all the way around (safety for misconfig)
      if (hours.length > 24) break;
      // If stepping by gap would skip bedTime, break
      if (hour == bedTime) break;
      // If stepping by gap would pass bedTime (for non-multiples), break
      if ((wakeTime < bedTime && hour > bedTime) ||
          (wakeTime > bedTime && hour > bedTime && hour < wakeTime)) {
        break;
      }
    }
    return hours;
  }
}

class EnergyPoint {
  final int hour;
  final double energy;

  EnergyPoint(this.hour, this.energy);
}
