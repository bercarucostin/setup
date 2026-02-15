import 'package:Watt/utils/utils.dart';

class UserData {
  final String? fullName;
  final String? birthday;
  final String? chronotype;
  final String? wakeTime;
  final String? bedTime;
  final int? wakeHour;
  final int? bedHour;
  final String? goal;

  const UserData({
    this.fullName,
    this.birthday,
    this.chronotype,
    this.wakeTime,
    this.bedTime,
    this.wakeHour,
    this.bedHour,
    this.goal,
  });

  UserData copyWith({
    String? fullName,
    String? birthday,
    String? chronotype,
    String? wakeTime,
    String? bedTime,
    int? wakeHour,
    int? bedHour,
    String? goal,
  }) {
    return UserData(
      fullName: fullName ?? this.fullName,
      birthday: birthday ?? this.birthday,
      chronotype: chronotype ?? this.chronotype,
      wakeTime: wakeTime ?? this.wakeTime,
      bedTime: bedTime ?? this.bedTime,
      wakeHour: wakeHour ?? this.wakeHour,
      bedHour: bedHour ?? this.bedHour,
      goal: goal ?? this.goal,
    );
  }

  Map<String, dynamic> toFirestoreMap(String email) {
    return {
      'name': fullName,
      'birthday': birthday,
      'chronotype': chronotype,
      'wakeTime': wakeTime,
      'bedTime': bedTime,
      'wakeHour': wakeHour,
      'bedHour': bedHour,
      'email': email,
      'createdAt': nowTimestampString(),
      'goal': goal,
    };
  }

  bool get isComplete =>
      chronotype != null && wakeTime != null && bedTime != null;
}
