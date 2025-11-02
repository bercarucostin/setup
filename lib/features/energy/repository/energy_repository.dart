import 'package:setup/features/energy/models/energy_feedback.dart';
import 'package:setup/features/energy/models/energy_model.dart';
import 'package:setup/features/firestore/repository/firestore.dart';

class EnergyRepository {
  final FirestoreRepository _firestoreRepo;
  EnergyRepository(this._firestoreRepo);

  int _epochDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;

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

  Future<void> saveUserEnergyFeedback({
    required String userId,
    required EnergyFeedbackRecord record,
  }) async {
    final String todayEpoch = _epochDay(DateTime.now()).toString();

    // 1. Ensure the day doc exists (it's okay to just upsert metadata or even empty map).
    await _firestoreRepo.saveDataInSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyFeedbackDays',
      subDocId: todayEpoch,
      data: {
        'day': todayEpoch, // optional, useful for listing days later
        'lastUpdated': DateTime.now().toIso8601String(),
      },
      merge: true,
    );

    // 2. Save the actual feedback for this specific hour
    await _firestoreRepo.saveDataInSubcollection(
      parentCollectionPath: 'users/$userId/energyFeedbackDays',
      parentDocId: todayEpoch,
      subcollectionPath: 'feedback',
      subDocId: record.hour.toString(), // one doc per hour block (e.g. "14")
      data: record.toFirestore(),
      merge: true,
    );
  }

  Future<Map<int, EnergyFeedbackRecord>> fetchUserEnergyFeedbackForToday(
    String userId,
  ) async {
    final String todayEpoch = _epochDay(DateTime.now()).toString();

    // We'll use the same pattern you already use in fetchUserEventsForToday:
    // getEntireSubSubcollection(parent -> sub -> subSub)
    final snap = await _firestoreRepo.getEntireSubSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyFeedbackDays',
      subDocId: todayEpoch,
      subSubcollectionPath: 'feedback',
    );

    if (snap.docs.isEmpty) {
      return <int, EnergyFeedbackRecord>{};
    }

    final Map<int, EnergyFeedbackRecord> result = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      // Each doc is keyed by hour ("14", "15", etc.), and has:
      // { hour, feedback: "match", predictedEnergy, ts }
      final record = EnergyFeedbackRecord.fromFirestore({
        ...data,
        'hour': data['hour'] ?? int.tryParse(doc.id),
      });

      result[record.hour] = record;
    }

    return result;
  }
}
