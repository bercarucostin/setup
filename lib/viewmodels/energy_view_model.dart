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
          'EnergyModel is not initialized. Call fetchEnergyModel first.');
    }

    predictedEnergy.clear();
    final wakeTime = _model!.wakeTime; // Get wakeTime from the model
    for (int i = 0; i < 16; i++) {
      // Limit to 16 hours after wakeTime
      final hour =
          ((wakeTime + i) % 24).round(); // Calculate hour within 24-hour format
      final energy = _model!.predict(hour, []);
      predictedEnergy.add(EnergyPoint(hour, energy));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> updateModel(int hour, double actualEnergy, String userId) async {
    if (_model == null) {
      throw Exception(
          'EnergyModel is not initialized. Call fetchEnergyModel first.');
    }

    await _model!
        .update(hour, actualEnergy, userId); // Update and save to Firestore
    notifyListeners(); // Notify listeners after updating the model
  }
}

class EnergyPoint {
  final int hour;
  final double energy;

  EnergyPoint(this.hour, this.energy);
}
