// lib/router/router_provider.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:Watt/features/auth/models/auth_state.dart';
import 'package:Watt/features/auth/providers/auth_controller_provider.dart';
import 'package:Watt/features/auth/providers/providers.dart';

import 'package:Watt/screens/auth/sign_in.dart';
import 'package:Watt/screens/auth/sign_up.dart';
import 'package:Watt/screens/checking_screen.dart';
import 'package:Watt/screens/home_screen.dart';

import 'package:Watt/screens/profile_configuration/onboarding_flow_screen.dart';

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
  ref.listen<bool>(
    accountDeletionInProgressProvider,
    (_, __) => refresh.notify(),
  );

  ref.onDispose(refresh.dispose);
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    //observers: [RouteLoggingObserver()],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.uri.path;

      final isLogin = loc == '/login';
      final isSignup = loc == '/signup';
      final isAuthPage = isLogin || isSignup;
      final isOnboarding = loc == '/onboarding';
      final isCheckingRoute = loc == '/checking';

      final isDeleting = ref.read(accountDeletionInProgressProvider);

      // debugPrint(
      //   'ROUTER redirect check: loc=$loc full=${state.uri} '
      //   'auth=${auth.runtimeType} deleting=$isDeleting',
      // );

      final isCheckingState =
          isDeleting || auth is AuthLoading || auth is CheckingProfile;

      if (isCheckingState) {
        final msg = isDeleting
            ? 'All your data is being fully removed from our records!'
            : (auth is CheckingProfile)
            ? 'Getting things ready for you!'
            : 'Please wait until we get you in!';

        final encoded = Uri.encodeComponent(msg);

        // If we're already on /checking, keep us there but update the query
        return loc == '/checking'
            ? '/checking?m=$encoded'
            : '/checking?m=$encoded';
      }

      // 2) If we are on /checking but no longer checking, move on
      if (isCheckingRoute) {
        if (auth is Unauthenticated) return '/login';
        if (auth is IncompleteProfile) return '/onboarding';
        if (auth is Authenticated) return '/';
        return '/login';
      }

      // 3) Not signed in -> only allow /login and /signup
      if (auth is Unauthenticated) {
        return isAuthPage ? null : '/login';
      }

      // 4) Signed in but incomplete -> force onboarding
      if (auth is IncompleteProfile) {
        return isOnboarding ? null : '/onboarding';
      }

      // 5) Signed in and complete -> block auth/onboarding pages
      if (auth is Authenticated) {
        if (isAuthPage || isOnboarding) return '/';
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingFlowScreen(),
      ),
      GoRoute(
        path: '/checking',
        builder: (_, state) =>
            CheckingScreen(message: state.uri.queryParameters['m'] ?? '…'),
      ),
    ],
  );
});

class RouteLoggingObserver extends NavigatorObserver {
  void _log(
    String action,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    final name = route?.settings.name;
    final prevName = previousRoute?.settings.name;
    // name is often null with go_router; still useful for push/pop visibility
    debugPrint('ROUTER $action | name=$name | from=$prevName | route=$route');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('PUSH', route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log('REPLACE', newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('POP', route, previousRoute);
    super.didPop(route, previousRoute);
  }
}
