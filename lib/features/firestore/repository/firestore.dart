import 'package:cloud_firestore/cloud_firestore.dart';

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
}
