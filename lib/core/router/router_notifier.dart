// core/router/router_notifier.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/auth/providers/providers.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/models/auth_state.dart';
import 'package:go_router/go_router.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref ref;

  RouterNotifier(this.ref) {
    // Re-run redirects when auth state changes
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = ref.read(authControllerProvider);
    final location = state.uri.toString();

    final isAuthFlow = location == '/login' || location == '/signup';
    final isOnboardingFlow = location.startsWith('/onboarding');

    // 1. Not signed in -> only allow /login or /signup
    if (authState is Unauthenticated) {
      if (!isAuthFlow) {
        return '/login';
      }
      return null;
    }

    // 2. Signed in BUT profile incomplete -> force /onboarding
    if (authState is IncompleteProfile) {
      if (!isOnboardingFlow) {
        return '/onboarding';
      }
      return null;
    }

    // 3. Signed in AND profile complete
    //    If they try to go back to /login or /signup, send them home
    if (authState is Authenticated && isAuthFlow) {
      return '/';
    }

    // 4. Otherwise allow navigation
    return null;
  }
}
