import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/firestore/repository/firestore.dart';

class EnergyRepository {
  final FirestoreRepository _firestoreRepo;
  EnergyRepository(this._firestoreRepo);

  Future<EnergyModel?> fetchUserEnergyModel(
    Map<String, dynamic> profile,
    String userId,
  ) async {
    // final userDoc = await _firestoreRepo.getData(
    //   collectionPath: 'users',
    //   docId: userId,
    // );

    final energyDoc = await _firestoreRepo.getDataFromSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyModel',
      subDocId: 'default',
    );
    if (energyDoc.exists) {
      return EnergyModel.fromFirestore(profile, energyDoc.data()!);
    }
    return null;
  }

  Future<EnergyModel?> fetchDefaultEnergyModel(
    String chronotype,
    Map<String, dynamic> profile,
    String userId,
  ) async {
    // final userDoc = await _firestoreRepo.getData(
    //   collectionPath: 'users',
    //   docId: userId,
    // );

    final defaultEnergyDoc = await _firestoreRepo.getData(
      collectionPath: 'energyModelDefaults',
      docId: chronotype,
    );

    return EnergyModel.fromFirestore(profile, defaultEnergyDoc.data()!);
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

  Future<void> deleteEnergyModel(String userId) {
    return _firestoreRepo.deleteSubDocument(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyModel',
      subDocId: 'default',
    );
  }
}
