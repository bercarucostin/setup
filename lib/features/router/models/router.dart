// lib/router/router_provider.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peak_flow/features/auth/models/auth_state.dart';
import 'package:peak_flow/features/auth/providers/auth_controller_provider.dart';

import 'package:peak_flow/screens/auth/sign_in.dart';
import 'package:peak_flow/screens/auth/sign_up.dart';
import 'package:peak_flow/screens/checking_screen.dart';

import 'package:peak_flow/screens/profile_configuration/onboarding_flow_screen.dart';

/// Minimal Listenable (NOT ChangeNotifier) for go_router refreshListenable.
class RouterRefreshListenable implements Listenable {
  final Set<VoidCallback> _listeners = <VoidCallback>{};
  bool _scheduled = false;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notify() {
    if (_scheduled) return;
    _scheduled = true;

    scheduleMicrotask(() {
      _scheduled = false;
      final snapshot = List<VoidCallback>.from(_listeners);
      for (final l in snapshot) {
        l();
      }
    });
  }

  void dispose() => _listeners.clear();
}

final routerRefreshProvider = Provider<RouterRefreshListenable>((ref) {
  final refresh = RouterRefreshListenable();

  ref.listen<AuthState>(authControllerProvider, (_, __) => refresh.notify());

  ref.onDispose(refresh.dispose);
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,

    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.uri.path;

      final isLogin = loc == '/login';
      final isSignup = loc == '/signup';
      final isAuthPage = isLogin || isSignup;
      final isOnboarding = loc == '/onboarding';

      // While figuring auth/profile, don't bounce around.
      if (auth is AuthLoading || auth is CheckingProfile) return null;

      // Not signed in -> only allow /login and /signup
      if (auth is Unauthenticated) {
        return isAuthPage ? null : '/login';
      }

      // Signed in but incomplete -> force onboarding
      if (auth is IncompleteProfile) {
        return isOnboarding ? null : '/onboarding';
      }

      // Signed in and complete -> block auth/onboarding pages
      if (auth is Authenticated) {
        if (isAuthPage || isOnboarding) return '/';
        return null;
      }

      return null;
    },

    routes: [
      GoRoute(path: '/', builder: (_, __) => const RootGate()),
      GoRoute(path: '/login', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingFlowScreen(),
      ),
    ],
  );
});
