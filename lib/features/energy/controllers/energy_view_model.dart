import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/repository/repository.dart';
import '../models/energy_model.dart';

class EnergyViewModel extends ChangeNotifier {
  final EnergyRepository _repository;
  EnergyViewModel(this._repository);

  EnergyModel? _model;
  final List<EnergyPoint> predictedEnergy = [];

  Future<void> fetchEnergyModel(String userId, String chronotype) async {
    // First try user-specific model
    var model = await _repository.fetchUserEnergyModel(userId);

    // Fallback: if no user-specific model, load defaults
    model ??= await _repository.fetchDefaultEnergyModel(chronotype);

    if (model != null) {
      _model = model;
      notifyListeners();
    } else {
      // Optional: handle case where no model was found at all
      debugPrint(
        'No energy model found for user $userId or default $chronotype',
      );
    }
  }

  void computeEnergyPrediction() {
    if (_model == null) {
      throw Exception(
        'EnergyModel is not initialized. Call fetchEnergyModel first.',
      );
    }

    predictedEnergy.clear();
    final wakeTime = _model!.wakeTime;
    final bedTime = _model!.bedTime;
    var hour = wakeTime;

    while (hour != bedTime) {
      final energy = _model!.predict(hour!, []);
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

    // Update local model
    _model!.update(hour, actualEnergy, userId);

    // Persist updated model using the repository
    await _repository.saveEnergyModel(userId, _model!);

    notifyListeners();
  }

  List<int> getDisplayedHours({int gap = 3}) {
    if (_model == null) return [];
    final wakeTime = _model!.wakeTime;
    final bedTime = _model!.bedTime;
    List<int> hours = [];
    int? hour = wakeTime;
    while (hour != bedTime) {
      hours.add(hour!);
      hour = (hour + gap) % 24;
      if (hours.length > 24) break;
      if (hour == bedTime) break;
      if ((wakeTime! < bedTime! && hour > bedTime) ||
          (wakeTime > bedTime && hour > bedTime && hour < wakeTime)) {
        break;
      }
    }
    return hours;
  }
}
