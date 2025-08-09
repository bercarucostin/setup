import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/firestore/repository/firestore.dart';

class EnergyRepository {
  final FirestoreRepository _firestoreRepo;
  EnergyRepository(this._firestoreRepo);

  Future<EnergyModel?> fetchUserEnergyModel(String userId) async {
    final userDoc = await _firestoreRepo.getData(
      collectionPath: 'users',
      docId: userId,
    );

    final energyDoc = await _firestoreRepo.getDataFromSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyModel',
      subDocId: 'default',
    );
    if (userDoc.exists && energyDoc.exists) {
      return EnergyModel.fromFirestore(userDoc.data()!, energyDoc.data()!);
    }
    return null;
  }

  Future<EnergyModel?> fetchDefaultEnergyModel(
    String chronotype,
    String userId,
  ) async {
    final userDoc = await _firestoreRepo.getData(
      collectionPath: 'users',
      docId: userId,
    );

    final defaultEnergyDoc = await _firestoreRepo.getData(
      collectionPath: 'energyModelDefaults',
      docId: chronotype,
    );

    return EnergyModel.fromFirestore(userDoc.data()!, defaultEnergyDoc.data()!);
  }

  Future<void> saveEnergyModel(String userId, EnergyModel model) {
    return _firestoreRepo.saveDataInSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyModel',
      subDocId: 'default',
      data: model.toFirestore(),
    );
  }
}
