import 'package:cloud_firestore/cloud_firestore.dart';
import 'energy_model.dart';

class User {
  final String id;
  final String name;
  final String chronotype;

  User({
    required this.id,
    required this.name,
    required this.chronotype,
  });

  // Factory constructor to create a User object from Firestore data
  factory User.fromFirestore(String id, Map<String, dynamic> data) {
    return User(
      id: id,
      name: data['name'] ?? '',
      chronotype: data['chronotype'] ?? 'default',
    );
  }

  // Method to convert a User object to Firestore data
  Map<String, dynamic> toFirestore() {
    return {'name': name, 'chronotype': chronotype};
  }

  // Fetch the associated EnergyModel from the subcollection
  Future<EnergyModel?> fetchEnergyModel() async {
    final energyModelDoc = await FirebaseFirestore.instance
        .collection('User')
        .doc(id)
        .collection('energyModel')
        .doc('default') // Assuming a single document named 'default'
        .get();

    if (energyModelDoc.exists) {
      return EnergyModel.fromFirestore(energyModelDoc.data()!);
    }
    return null; // Return null if no energy model exists
  }
}
