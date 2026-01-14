import 'package:intl/intl.dart';

DateTime nowTimestamp() {
  return DateTime.now();
}

String nowTimestampString() {
  return DateTime.now().toIso8601String();
}

String todayDateString() {
  return customDateString(nowTimestamp());
}

String customDateString(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

int hourDifference(int startHour, int endHour) {
  return (endHour - startHour) % 24;
}

bool isBetweenHours(int hour, int startHour, int endHour) {
  if (startHour <= endHour) {
    return hour >= startHour && hour <= endHour;
  } else {
    return hour >= startHour || hour <= endHour;
  }
}

DateTime dateWokeUp(int wakeHour, int bedHour) {
  final now = nowTimestamp();
  int hour = now.hour;
  if (isBetweenHours(hour, 0, bedHour) &&
      !isBetweenHours(wakeHour, 0, bedHour)) {
    return now.subtract(Duration(days: 1));
  }
  return now;
}

double doubleWithFallback(Map<String, dynamic> m, String k, double fallback) {
  final v = m[k];
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  throw StateError('Field "$k" must be a number, got ${v.runtimeType}');
}

int intWithFallback(Map<String, dynamic> m, String k, int fallback) {
  final v = m[k];
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  throw StateError('Field "$k" must be a number, got ${v.runtimeType}');
}
