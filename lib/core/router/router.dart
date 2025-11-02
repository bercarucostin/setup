import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setup/screens/home_screen.dart';
import 'package:setup/screens/auth/sign_in.dart';
import 'package:setup/screens/auth/sign_up.dart';
import 'package:setup/screens/profile_configuration/chronotype_screen.dart';
import 'package:setup/screens/profile_configuration/onboarding_flow_screen.dart';
import 'package:setup/screens/profile_configuration/sleep_schedule.dart';
import 'package:setup/screens/profile_configuration/user_basic_information.dart';

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

      // NEW unified onboarding flow
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingFlowScreen(),
      ),
    ],
  );
});
