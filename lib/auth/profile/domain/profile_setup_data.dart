class ProfileSetupData {
  final String? fullName;
  final String? birthday;
  final String? chronotype;
  final String? wakeTime;
  final String? bedTime;
  final String? goal;

  const ProfileSetupData({
    this.fullName,
    this.birthday,
    this.chronotype,
    this.wakeTime,
    this.bedTime,
    this.goal,
  });

  ProfileSetupData copyWith({
    String? fullName,
    String? birthday,
    String? chronotype,
    String? wakeTime,
    String? bedTime,
    String? goal,
  }) {
    return ProfileSetupData(
      fullName: fullName ?? this.fullName,
      birthday: birthday ?? this.birthday,
      chronotype: chronotype ?? this.chronotype,
      wakeTime: wakeTime ?? this.wakeTime,
      bedTime: bedTime ?? this.bedTime,
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
      'email': email,
      'createdAt': DateTime.now(),
      'goal': goal,
    };
  }

  bool get isComplete =>
      fullName != null &&
      birthday != null &&
      chronotype != null &&
      wakeTime != null &&
      bedTime != null &&
      goal != null;
}
