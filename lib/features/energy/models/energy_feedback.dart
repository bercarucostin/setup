enum EnergyFeedback { muchHigher, higher, match, lower, muchLower }

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
      return EnergyFeedback.match;
  }
}

class EnergyFeedbackRecord {
  final int hour; // 0..23
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
      'ts': DateTime.now().toIso8601String(),
    };
  }

  factory EnergyFeedbackRecord.fromFirestore(Map<String, dynamic> data) {
    final rawHour = data['hour'];
    final hour = rawHour is int ? rawHour : int.tryParse('$rawHour') ?? 0;

    return EnergyFeedbackRecord(
      hour: hour.clamp(0, 23),
      feedback: stringToFeedback((data['feedback'] ?? 'match') as String),
      predictedEnergy: (data['predictedEnergy'] as num?)?.toDouble(),
    );
  }
}
