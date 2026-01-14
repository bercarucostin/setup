import 'package:watt/utils/utils.dart';

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
  double wS;
  double wC;
  num circadianPeakHour;
  int hoursSlept;
  double sPrev;
  int wakeHour;
  int bedHour;
  final double? predictedEnergy;

  EnergyFeedbackRecord({
    required this.hour,
    required this.feedback,
    required this.wS,
    required this.wC,
    required this.circadianPeakHour,
    required this.hoursSlept,
    required this.sPrev,
    required this.wakeHour,
    required this.bedHour,
    this.predictedEnergy,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'hour': hour,
      'feedback': feedbackToString(feedback),
      'wS': wS,
      'wC': wC,
      'circadianPeakHour': circadianPeakHour,
      'hoursSlept': hoursSlept,
      'sPrev': sPrev,
      'wakeHour': wakeHour,
      'bedHour': bedHour,
      if (predictedEnergy != null) 'predictedEnergy': predictedEnergy,
      'createdAt': nowTimestampString(),
    };
  }

  factory EnergyFeedbackRecord.fromFirestore(Map<String, dynamic> data) {
    final rawHour = data['hour'];
    final hour = rawHour is int ? rawHour : int.tryParse('$rawHour') ?? 0;
    return EnergyFeedbackRecord(
      hour: hour,
      feedback: stringToFeedback(data['feedback'] as String),
      wS: data['wS'] as double,
      wC: data['wC'] as double,
      circadianPeakHour: data['circadianPeakHour'] as num,
      hoursSlept: data['hoursSlept'] as int,
      sPrev: data['sPrev'] as double,
      wakeHour: data['wakeHour'] as int,
      bedHour: data['bedHour'] as int,
      predictedEnergy: data['predictedEnergy'] as double?,
    );
  }
}
