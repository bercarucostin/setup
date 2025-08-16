import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:setup/features/energy/models/event.dart';

class FirestoreRepository {
  final FirebaseFirestore _firestore;

  FirestoreRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Saves data to a collection.
  ///
  /// If [docId] is provided:
  ///   - Uses that ID for the document.
  /// If [docId] is not provided:
  ///   - Generates a random ID locally and saves to that document.
  ///
  /// Returns the DocumentReference of the saved document.
  ///
  /// Example usage:
  // Auto ID:
  // final ref = await firestoreRepository.saveData(
  //   collectionPath: 'feedback',
  //   data: {'message': 'Hello'},
  // );
  // print(ref.id); // random ID

  // // Specific ID:
  // await firestoreRepository.saveData(
  //   collectionPath: 'users',
  //   docId: user.uid,
  //   data: {'email': user.email},
  // );

  // GET DATA
  Future<DocumentSnapshot<Map<String, dynamic>>> getData({
    required String collectionPath,
    required String docId,
  }) async {
    final docRef = _firestore.collection(collectionPath).doc(docId);
    return await docRef.get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDataFromSubcollection({
    required String parentCollectionPath,
    required String parentDocId,
    required String subcollectionPath,
    required String subDocId,
  }) async {
    final subDocRef = _firestore
        .collection(parentCollectionPath)
        .doc(parentDocId)
        .collection(subcollectionPath)
        .doc(subDocId);

    return await subDocRef.get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getEntireCollection({
    required String entireCollectionPath,
  }) async {
    final colRef = _firestore.collection(entireCollectionPath);

    return await colRef.get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getEntireSubSubcollection({
    required String parentCollectionPath,
    required String parentDocId,
    required String subcollectionPath,
    required String subDocId,
    required String subSubcollectionPath,
  }) async {
    final subSubDocRef = _firestore
        .collection(parentCollectionPath)
        .doc(parentDocId)
        .collection(subcollectionPath)
        .doc(subDocId)
        .collection(subSubcollectionPath);

    return await subSubDocRef.get();
  }

  /// Saves data in a subcollection of a document.
  // Let Firestore generate an ID
  // final docRef = await firestoreRepository.saveDataInSubcollection(
  //   parentCollectionPath: 'users',
  //   parentDocId: user.uid,
  //   subcollectionPath: 'logs',
  //   data: {'action': 'login', 'timestamp': FieldValue.serverTimestamp()},
  // );
  // docRef.id is the random ID

  // specific ID example:
  // await firestoreRepository.saveDataInSubcollection(
  //   parentCollectionPath: 'users',
  //   parentDocId: user.uid,
  //   subcollectionPath: 'energyModel',
  //   subDocId: 'default',
  //   data: {'hoursSlept': 8},
  // );

  // STORE DATA
  Future<DocumentReference<Map<String, dynamic>>> saveData({
    required String collectionPath,
    String? docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    final collection = _firestore.collection(collectionPath);

    // If docId is not provided, pre-generate one
    final DocumentReference<Map<String, dynamic>> docRef =
        docId != null ? collection.doc(docId) : collection.doc();

    await docRef.set(data, SetOptions(merge: merge));
    return docRef;
  }

  Future<DocumentReference<Map<String, dynamic>>> saveDataInSubcollection({
    required String parentCollectionPath,
    required String parentDocId,
    required String subcollectionPath,
    String? subDocId, // optional
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    final parentDoc = _firestore
        .collection(parentCollectionPath)
        .doc(parentDocId);

    final subCollection = parentDoc.collection(subcollectionPath);

    if (subDocId != null) {
      // Use the provided ID
      final subDoc = subCollection.doc(subDocId);
      await subDoc.set(data, SetOptions(merge: merge));
      return subDoc;
    } else {
      // Generate a random ID
      final newDoc = await subCollection.add(data);
      return newDoc;
    }
  }

  // can be more generalized? I don't know, it's super specific
  Future<DocumentReference<Map<String, dynamic>>> saveUserEvent({
    required String userId,
    required String epochDay, // e.g., DateTime.now() in user's local tz
    required Map<String, dynamic> eventData,
  }) async {
    final dayRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('eventDays')
        .doc(epochDay);

    final eventsCol = dayRef.collection('events');
    final eventRef = eventsCol.doc(); // generates an auto ID

    // One atomic write: ensure day doc exists, then create the event
    final batch = _firestore.batch();

    batch.set(
      dayRef,
      {'epochDay': epochDay},
      SetOptions(merge: true), // upsert if missing
    );

    batch.set(eventRef, eventData);

    await batch.commit();
    return eventRef;
  }

  //DELETE DATA
  Future<void> deleteUserEvent({
    required String userId,
    required String eventId,
    required String epochDay,
  }) async {
    final eventRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('eventDays')
        .doc(epochDay)
        .collection('events')
        .doc(eventId);

    await eventRef.delete();
  }
}
