import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watt/features/energy/models/event.dart';
import 'package:watt/features/firestore/repository/firestore.dart';

class EventRepository {
  EventRepository(this._firestoreRepo, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirestoreRepository _firestoreRepo;
  final FirebaseFirestore _firestore;

  int _epochDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;

  String _todayEpochDay() => _epochDay(DateTime.now()).toString();

  // --------------------------
  // Defaults (public collection)
  // --------------------------
  Future<List<Event>> fetchAllDefaultEvents() async {
    final snap = await _firestoreRepo.getEntireCollection(
      entireCollectionPath: 'events',
    );
    if (snap.docs.isEmpty) return const <Event>[];

    return snap.docs.map((doc) {
      final data = doc.data();
      return Event.fromFirestore(data);
    }).toList();
  }

  // --------------------------
  // Today events (per-user)
  // --------------------------
  Stream<List<Event>> watchUserEventsForToday(String userId) {
    final day = _todayEpochDay();

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('eventDays')
        .doc(day)
        .collection('events')
        .snapshots()
        .map((qs) {
          final items = qs.docs.map((doc) {
            final data = doc.data();
            // attach id so UI can delete
            return Event.fromFirestore({...data, 'id': doc.id});
          }).toList();

          // Keep UI stable even if Firestore has no ordering
          items.sort((a, b) {
            final sa = (a.startHour ?? 0).toDouble();
            final sb = (b.startHour ?? 0).toDouble();
            final cmp = sa.compareTo(sb);
            if (cmp != 0) return cmp;
            return a.name.compareTo(b.name);
          });

          return items;
        });
  }

  Future<void> addEventFromTemplate({
    required String userId,
    required Event template,
    required int startHour,
    required double duration,
  }) async {
    // Build event payload from the template defaults + selected time
    final data = template.toFirestore();

    // enforce the fields your screen needs
    data['name'] = template.name;
    data['startHour'] = startHour;
    data['duration'] = duration;

    await _firestoreRepo.saveUserEvent(
      userId: userId,
      epochDay: _todayEpochDay(),
      eventData: data,
    );
  }

  Future<void> deleteEvent({
    required String userId,
    required String eventId,
    required String epochDay,
  }) async {
    await _firestoreRepo.deleteUserEvent(
      userId: userId,
      eventId: eventId,
      epochDay: epochDay,
    );
  }

  String todayEpochDayForDeletes() => _todayEpochDay();
}
