import 'package:cloud_firestore/cloud_firestore.dart';

class UserFeedback {
  String userId;
  DateTime timestamp;
  String type; // e.g., 'wake_time', 'sleep_quality', 'actual_energy'
  num value;

  UserFeedback(
      {required this.userId,
      required this.timestamp,
      required this.type,
      required this.value});

  // Factory constructor to create UserFeedback from Firestore data
  factory UserFeedback.fromFirestore(Map<String, dynamic> data) {
    return UserFeedback(
      userId: data['userId'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'],
      value: data['value'],
    );
  }

  Future<void> saveToFirestore() async {
    final feedbackCollection =
        FirebaseFirestore.instance.collection('Feedback');
    await feedbackCollection.add(toFirestore());
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'value': value,
    };
  }
}
