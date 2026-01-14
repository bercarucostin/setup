import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watt/features/energy/models/event.dart';
import 'package:watt/features/firestore/repository/firestore.dart';
import 'package:watt/utils/utils.dart';

class EventRepository {
  EventRepository(this._firestoreRepo, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirestoreRepository _firestoreRepo;
  final FirebaseFirestore _firestore;

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

  // -------------------- Today's Events - Stream --------------------
  Stream<List<Event>> watchUserEventsForToday(String userId, DateTime today) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('eventDays')
        .doc(customDateString(today))
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
    required DateTime today,
    required Event template,
    required int startHour,
    required double intensity,
  }) async {
    // Build event payload from the template defaults + selected time
    final data = template.toFirestore();

    // enforce the fields your screen needs
    data['name'] = template.name;
    data['startHour'] = startHour;
    data['intensity'] = intensity;
    data['createdAt'] = nowTimestampString();

    await _firestoreRepo.saveUserEvent(
      userId: userId,
      epochDay: customDateString(today),
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
}
