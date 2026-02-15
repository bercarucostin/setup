import 'package:watt/utils/utils.dart';

enum SleepQuality { veryPoor, poor, okay, good, great }

String sleepQualityToString(SleepQuality q) {
  switch (q) {
    case SleepQuality.veryPoor:
      return 'veryPoor';
    case SleepQuality.poor:
      return 'poor';
    case SleepQuality.okay:
      return 'okay';
    case SleepQuality.good:
      return 'good';
    case SleepQuality.great:
      return 'great';
  }
}

SleepQuality stringToSleepQuality(String? raw) {
  switch (raw) {
    case 'veryPoor':
      return SleepQuality.veryPoor;
    case 'poor':
      return SleepQuality.poor;
    case 'okay':
      return SleepQuality.okay;
    case 'good':
      return SleepQuality.good;
    case 'great':
      return SleepQuality.great;
    default:
      return SleepQuality.okay;
  }
}

class SleepQualityRecord {
  /// The user-local day key you already use everywhere (based on wake/bed rules),
  /// formatted as yyyy-MM-dd.
  final String epochDay;

  final SleepQuality quality;

  /// Optional: keep wake/bed context used to compute epochDay (useful for audits)
  final int? wakeHour;
  final int? bedHour;

  /// Optional: if you later want to correlate with energy forecast inputs
  final int? hoursSlept;

  SleepQualityRecord({
    required this.epochDay,
    required this.quality,
    this.wakeHour,
    this.bedHour,
    this.hoursSlept,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'epochDay': epochDay,
      'sleepQuality': sleepQualityToString(quality),
      if (wakeHour != null) 'wakeHour': wakeHour,
      if (bedHour != null) 'bedHour': bedHour,
      if (hoursSlept != null) 'hoursSlept': hoursSlept,
      // keep consistent with the rest of your project
      'createdAt': nowTimestampString(),
    };
  }

  factory SleepQualityRecord.fromFirestore(Map<String, dynamic> data) {
    return SleepQualityRecord(
      epochDay: (data['epochDay'] as String?) ?? '',
      quality: stringToSleepQuality(data['sleepQuality'] as String?),
      wakeHour: data['wakeHour'] as int?,
      bedHour: data['bedHour'] as int?,
      hoursSlept: data['hoursSlept'] as int?,
    );
  }
}
