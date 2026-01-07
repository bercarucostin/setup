import 'package:watt/features/energy/models/energy_feedback.dart';
import 'package:watt/features/energy/models/energy_model.dart';
import 'package:watt/features/energy/models/energy_point.dart';
import 'package:watt/features/energy/models/event.dart';
import 'package:watt/features/firestore/repository/firestore.dart';

class EnergyRepository {
  final FirestoreRepository _firestoreRepo;
  EnergyRepository(this._firestoreRepo);

  int _epochDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;

  // -------------------- MODEL --------------------

  Future<EnergyModel> loadOrDefaultModel({
    required String userId,
    required Map<String, dynamic> profile,
    required String chronotype,
  }) async {
    final energyDoc = await _firestoreRepo.getDataFromSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyModel',
      subDocId: 'default',
    );

    if (energyDoc.exists && energyDoc.data() != null) {
      return EnergyModel.fromFirestore(profile, energyDoc.data()!);
    }

    final defaultDoc = await _firestoreRepo.getData(
      collectionPath: 'energyModelDefaults',
      docId: chronotype,
    );

    final data = defaultDoc.data();
    if (data == null) {
      throw StateError(
        'Missing energyModelDefaults doc for chronotype=$chronotype',
      );
    }

    final model = EnergyModel.fromFirestore(profile, data);

    // ✅ Persist immediately so next load is stable
    await saveEnergyModel(userId, model);

    return model;
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

  // -------------------- EVENTS (today) --------------------

  Future<List<Event>> fetchUserEventsForToday(String userId) async {
    final todayEpoch = _epochDay(DateTime.now()).toString();

    final snap = await _firestoreRepo.getEntireSubSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'eventDays',
      subDocId: todayEpoch,
      subSubcollectionPath: 'events',
    );

    if (snap.docs.isEmpty) return const <Event>[];

    return snap.docs.map((doc) {
      final data = doc.data();
      return Event.fromFirestore({...data, 'id': doc.id});
    }).toList();
  }

  // -------------------- PREDICTION (daily curve) --------------------
  //
  // IMPORTANT: compute wake->bed ALWAYS, so "lastHour" is truly bedtime.
  // This prevents accidentally setting bedHourLastDay to "now".
  //
  List<EnergyPoint> buildDailyEnergyCurve({
    required EnergyModel model,
    required List<Event> events,
  }) {
    final pts = <EnergyPoint>[];

    final start = model.defaultWakeHour;
    final end = model.defaultBedHour;

    // first point
    pts.add(EnergyPoint(start, model.predict(start, true, false, events)));

    int h = (start + 1) % 24;

    while (h != end) {
      pts.add(EnergyPoint(h, model.predict(h, false, false, events)));
      h = (h + 1) % 24;
    }

    // last point at bedtime (lastHour = true)
    pts.add(EnergyPoint(end, model.predict(end, false, true, events)));

    return pts;
  }

  // -------------------- FEEDBACK --------------------

  Future<void> saveUserEnergyFeedback({
    required String userId,
    required EnergyFeedbackRecord record,
  }) async {
    final String todayEpoch = _epochDay(DateTime.now()).toString();

    await _firestoreRepo.saveDataInSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyFeedbackDays',
      subDocId: todayEpoch,
      data: {
        'day': todayEpoch,
        'lastUpdated': DateTime.now().toIso8601String(),
      },
      merge: true,
    );

    await _firestoreRepo.saveDataInSubcollection(
      parentCollectionPath: 'users/$userId/energyFeedbackDays',
      parentDocId: todayEpoch,
      subcollectionPath: 'feedback',
      subDocId: record.hour.toString(),
      data: record.toFirestore(),
      merge: true,
    );
  }

  Future<Map<int, EnergyFeedbackRecord>> fetchUserEnergyFeedbackForToday(
    String userId,
  ) async {
    final String todayEpoch = _epochDay(DateTime.now()).toString();

    final snap = await _firestoreRepo.getEntireSubSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyFeedbackDays',
      subDocId: todayEpoch,
      subSubcollectionPath: 'feedback',
    );

    if (snap.docs.isEmpty) return <int, EnergyFeedbackRecord>{};

    final Map<int, EnergyFeedbackRecord> result = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      final record = EnergyFeedbackRecord.fromFirestore({
        ...data,
        'hour': data['hour'] ?? int.tryParse(doc.id),
      });
      result[record.hour] = record;
    }

    return result;
  }
}
