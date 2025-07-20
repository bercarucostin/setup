import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setup/screens/home_screen.dart';
import 'package:setup/screens/sign_in.dart';
import 'package:setup/screens/sign_up.dart';
import 'package:setup/screens/user_creation/chronotype_screen.dart';
import 'package:setup/screens/user_creation/sleep_schedule.dart';
import 'package:setup/screens/user_creation/user_basic_information.dart';

import 'router_notifier.dart';

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(
        path: '/complete-profile',
        builder: (_, __) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/chronotype',
        builder: (context, state) => const ChronotypeScreen(),
      ),
      GoRoute(
        path: '/sleep-schedule',
        builder: (context, state) => const SleepScheduleScreen(),
      ),
    ],
  );
});
