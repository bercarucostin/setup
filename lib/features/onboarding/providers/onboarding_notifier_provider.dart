import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Watt/features/auth/models/user_data.dart';

class OnboardingDraftNotifier extends Notifier<UserData> {
  @override
  UserData build() => const UserData();

  void updateNameAndBirthday(String name, String birthday) {
    state = state.copyWith(fullName: name, birthday: birthday);
  }

  void updateChronotype(String value) {
    state = state.copyWith(chronotype: value);
  }

  void updateSleepTimes(String wake, String bed, int wakeHour, int bedHour) {
    state = state.copyWith(
      wakeTime: wake,
      bedTime: bed,
      wakeHour: wakeHour,
      bedHour: bedHour,
    );
  }

  void updateGoal(String value) {
    state = state.copyWith(goal: value);
  }

  bool get isComplete => state.isComplete;
}

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftNotifier, UserData>(
      OnboardingDraftNotifier.new,
    );
