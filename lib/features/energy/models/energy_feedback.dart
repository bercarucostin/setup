// same enum you already have in your file
enum EnergyFeedback {
  muchHigher, // My energy was far higher
  higher, // My energy was slightly higher
  match, // Suggested energy was perfect
  lower, // My energy was slightly lower
  muchLower, // My energy was far lower
}

// convert enum -> string for Firestore
String feedbackToString(EnergyFeedback fb) {
  switch (fb) {
    case EnergyFeedback.muchHigher:
      return 'muchHigher';
    case EnergyFeedback.higher:
      return 'higher';
    case EnergyFeedback.match:
      return 'match';
    case EnergyFeedback.lower:
      return 'lower';
    case EnergyFeedback.muchLower:
      return 'muchLower';
  }
}

// convert string -> enum when reading from Firestore
EnergyFeedback stringToFeedback(String raw) {
  switch (raw) {
    case 'muchHigher':
      return EnergyFeedback.muchHigher;
    case 'higher':
      return EnergyFeedback.higher;
    case 'match':
      return EnergyFeedback.match;
    case 'lower':
      return EnergyFeedback.lower;
    case 'muchLower':
      return EnergyFeedback.muchLower;
    default:
      // fallback (if bad / unexpected value in DB)
      return EnergyFeedback.match;
  }
}

class EnergyFeedbackRecord {
  final int hour;
  final EnergyFeedback feedback;
  final double? predictedEnergy;

  EnergyFeedbackRecord({
    required this.hour,
    required this.feedback,
    this.predictedEnergy,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'hour': hour,
      'feedback': feedbackToString(feedback),
      if (predictedEnergy != null) 'predictedEnergy': predictedEnergy,
      'ts': DateTime.now().toIso8601String(), // optional audit trail
    };
  }

  factory EnergyFeedbackRecord.fromFirestore(Map<String, dynamic> data) {
    return EnergyFeedbackRecord(
      hour: data['hour'] as int,
      feedback: stringToFeedback(data['feedback'] as String),
      predictedEnergy: (data['predictedEnergy'] as num?)?.toDouble(),
    );
  }
}
