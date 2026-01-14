import 'package:watt/features/auth/providers/providers.dart';
import 'package:watt/features/energy/models/energy_feedback.dart';
import 'package:watt/features/energy/models/energy_model.dart';
import 'package:watt/features/energy/models/energy_point.dart';
import 'package:watt/features/energy/models/event.dart';
import 'package:watt/features/firestore/repository/firestore.dart';
import 'package:watt/utils/utils.dart';

class EnergyRepository {
  final FirestoreRepository _firestoreRepo;
  EnergyRepository(this._firestoreRepo);

  // -------------------- MODEL --------------------

  Future<EnergyModel> loadOrDefaultModel({
    required String userId,
    required Map<String, dynamic> profile,
  }) async {
    final energyDoc = await _firestoreRepo.getDataFromSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyModel',
      subDocId: 'default',
    );

    print(
      """Loading energy model for userId=$userId "
        "chronotype=${profile['chronotype']} energyDoc.exists=${energyDoc.exists}""",
    );

    if (energyDoc.exists && energyDoc.data() != null) {
      return EnergyModel.fromFirestore(profile, energyDoc.data()!);
    }

    final defaultDoc = await _firestoreRepo.getData(
      collectionPath: 'energyModelDefaults',
      docId: profile['chronotype'],
    );

    print(
      'Loaded default energy model for chronotype=${profile['chronotype']} exists=${defaultDoc.exists}',
    );

    final data = defaultDoc.data();
    if (data == null) {
      throw StateError(
        'Missing energyModelDefaults doc for chronotype=${profile['chronotype']}',
      );
    }

    print(data['circadianPeak']);

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

  // -------------------- Today's Events - One Time --------------------

  Future<List<Event>> fetchUserEventsForToday(String userId) async {
    final profileDoc = await _firestoreRepo.getData(
      collectionPath: 'users',
      docId: userId,
    );

    final profile = profileDoc.data();
    if (profile == null) {
      throw StateError('User profile not found for userId=$userId');
    }

    final today = dateWokeUp(profile['wakeHour'], profile['bedHour']);

    final snap = await _firestoreRepo.getEntireSubSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'eventDays',
      subDocId: customDateString(today),
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
    print("Energy points:");
    for (final point in pts) {
      print(
        '  ${point.hour.toString().padLeft(2, '0')}:00 → '
        '${point.energy.toStringAsFixed(2)} (${_energyLabel(point.energy)})',
      );
    }
    return pts;
  }

  // -------------------- FEEDBACK --------------------

  Future<void> saveUserEnergyFeedback({
    required String userId,
    required EnergyFeedbackRecord record,
  }) async {
    final profileDoc = await _firestoreRepo.getData(
      collectionPath: 'users',
      docId: userId,
    );

    final profile = profileDoc.data();
    if (profile == null) {
      throw StateError('User profile not found for userId=$userId');
    }

    final today = dateWokeUp(profile['wakeHour'], profile['bedHour']);

    await _firestoreRepo.saveDataInSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyFeedbackDays',
      subDocId: customDateString(today),
      data: {
        'day': customDateString(today),
        'lastUpdated': nowTimestampString(),
      },
      merge: true,
    );

    await _firestoreRepo.saveDataInSubcollection(
      parentCollectionPath: 'users/$userId/energyFeedbackDays',
      parentDocId: customDateString(today),
      subcollectionPath: 'feedback',
      subDocId: record.hour.toString(),
      data: record.toFirestore(),
      merge: true,
    );
  }

  Future<Map<int, EnergyFeedbackRecord>> fetchUserEnergyFeedbackForToday(
    String userId,
  ) async {
    final profileDoc = await _firestoreRepo.getData(
      collectionPath: 'users',
      docId: userId,
    );

    final profile = profileDoc.data();
    if (profile == null) {
      throw StateError('User profile not found for userId=$userId');
    }

    final today = dateWokeUp(profile['wakeHour'], profile['bedHour']);

    final snap = await _firestoreRepo.getEntireSubSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'energyFeedbackDays',
      subDocId: customDateString(today),
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

  String _energyLabel(double energy) {
    if (energy > 80) return 'Peak power';
    if (energy > 60) return 'In the zone';
    if (energy > 40) return 'Cruising';
    if (energy > 20) return 'Warming Up';
    return 'Running on fumes';
  }
}
