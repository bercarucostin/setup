import 'package:setup/features/energy/models/event.dart';
import 'package:setup/features/firestore/repository/firestore.dart';

class EventRepository {
  final FirestoreRepository _firestoreRepo;
  EventRepository(this._firestoreRepo);

  int _epochDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;

  Future<List<Event>> fetchUserEventsForToday(String userId) async {
    final snap = await _firestoreRepo.getEntireSubSubcollection(
      parentCollectionPath: 'users',
      parentDocId: userId,
      subcollectionPath: 'eventDays',
      subDocId: _epochDay(DateTime.now()).toString(),
      subSubcollectionPath: 'events',
    );
    if (snap.docs.isEmpty) {
      return const <Event>[];
    }
    return snap.docs.map((doc) {
      final data = doc.data();
      return Event.fromFirestore({...data, 'id': doc.id});
    }).toList();
  }

  Future<List<Event>> fetchAllDefaultEvents() async {
    final defaultEvents = await _firestoreRepo.getEntireCollection(
      entireCollectionPath: 'eventDefaults',
    );
    if (defaultEvents.docs.isEmpty) {
      return const <Event>[];
    }
    return defaultEvents.docs.map((doc) {
      final data = doc.data();
      return Event.fromFirestore(data);
    }).toList();
  }

  Future<Event?> fetchDefaultEvent(String event) async {
    final defaultEventDoc = await _firestoreRepo.getData(
      collectionPath: 'eventDefaults',
      docId: event,
    );

    return Event.fromFirestore(defaultEventDoc.data()!);
  }

  Future<void> saveEvent(String userId, Event event) {
    return _firestoreRepo.saveUserEvent(
      userId: userId,
      epochDay: _epochDay(DateTime.now()).toString(),
      eventData: event.toFirestore(),
    );
  }

  Future<void> deleteEvent(
    String userId,
    String eventId,
    String epochDay,
  ) async {
    await _firestoreRepo.deleteUserEvent(
      userId: userId,
      eventId: eventId,
      epochDay: epochDay,
    );
  }
}
